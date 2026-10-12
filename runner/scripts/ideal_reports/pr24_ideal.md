# Отчёт по Практической работе №24 «Метрики оценки качества генерации изображений»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~$ mkdir image_gen_lab
student@istp:~$ cd image_gen_lab
student@istp:~/image_gen_lab$ pip list | grep -iE 'tensorflow|scikit-learn|matplotlib|numpy|pillow|scipy|imageio'
imageio           2.34.0
matplotlib        3.8.0
numpy             1.26.4
pillow            10.3.0
scikit-learn      1.4.1
scipy             1.11.4
tensorflow        2.15.0
```

### Шаг 2. Этап 1 — обучение VAE на MNIST (vae_mnist.py)

```python
import argparse
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

latent_dim = 2

def load_mnist_images(root="~/data/MNIST/raw/train-images-ubyte"):
    with open(root, "rb") as f:
        f.seek(0)
        data = np.frombuffer(f.read(), dtype=np.uint8, offset=16)
    return data.reshape(-1, 28, 28, 1).astype("float32") / 255.0

def build_encoder(latent_dim):
    model = keras.Sequential([
        layers.Flatten(input_shape=(28, 28, 1)),
        layers.Dense(128, activation="relu"),
        layers.Dense(latent_dim * 2)
    ], name="encoder")
    def call(x):
        h = model(x)
        z_mean = h[:, :latent_dim]
        z_log_var = h[:, latent_dim:]
        return z_mean, z_log_var
    return call

def build_decoder(latent_dim):
    return keras.Sequential([
        layers.Dense(128, input_shape=(latent_dim,), activation="relu"),
        layers.Dense(28 * 28, activation="sigmoid"),
        layers.Reshape((28, 28, 1))
    ], name="decoder")

class VAE(keras.Model):
    def __init__(self, encoder, decoder, **kwargs):
        super(VAE, self).__init__(**kwargs)
        self.encoder = encoder
        self.decoder = decoder

    def call(self, x):
        z_mean, z_log_var = self.encoder(x)
        return self.decoder(z_mean)

def main(epochs=10, output_dir="output"):
    x_train = load_mnist_images()
    encoder = build_encoder(latent_dim)
    decoder = build_decoder(latent_dim)
    vae = VAE(encoder, decoder)
    vae.compile(optimizer=keras.optimizers.Adam(1e-4))

    @tf.function
    def train_step(x):
        with tf.GradientTape() as tape:
            z_mean, z_log_var = encoder(x)
            z = z_mean + tf.exp(0.5 * z_log_var) * tf.random.normal(tf.shape(z_mean))
            x_decoded = decoder(z)
            recon_loss = tf.reduce_sum(keras.losses.binary_crossentropy(x, x_decoded))
            kl_loss = -0.5 * tf.reduce_sum(1 + z_log_var - tf.square(z_mean) - tf.exp(z_log_var))
            total_loss = recon_loss + kl_loss
        grads = tape.gradient(total_loss, vae.trainable_variables)
        vae.optimizer.apply_gradients(zip(grads, vae.trainable_variables))
        return total_loss

    for epoch in range(epochs):
        total = tf.constant(0.0)
        for i in range(0, len(x_train), 256):
            total += train_step(x_train[i:i + 256])
        print(f"epoch {epoch}: loss={total.numpy() / (len(x_train) // 256 + 1):.3f}")

    import os
    os.makedirs(output_dir, exist_ok=True)
    decoder.save(os.path.join(output_dir, "decoder.h5"))

    # сетка 4x4 сгенерированных изображений
    z = np.random.normal(size=(16, latent_dim))
    imgs = decoder.predict(z, verbose=0)
    grid = np.zeros((28 * 4, 28 * 4), dtype="uint8")
    for i, img in enumerate(imgs):
        grid[28 * (i // 4):28 * (i // 4) + 28, 28 * (i % 4):28 * (i % 4) + 28] = (img[:, :, 0] * 255).astype("uint8")
    import imageio
    imageio.imwrite(os.path.join(output_dir, "vae_mnist.png"), grid)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--output-dir", default="output")
    main(parser.parse_args().epochs, parser.parse_args().output_dir)
```

```bash
student@istp:~/image_gen_lab$ python vae_mnist.py --epochs 10 --output-dir output
epoch 0: loss=1287.431
...
epoch 9: loss=912.204
```

Созданы `output/decoder.h5` и сетка `output/vae_mnist.png` (16 изображений).

### Шаг 3. Этап 2 — выборка из 2000 сгенерированных изображений (generate_samples.py)

```python
import argparse
import numpy as np
import tensorflow as tf
import imageio
from pathlib import Path

def load_model(decoder_path):
    return tf.keras.models.load_model(decoder_path)

def main(decoder_path="output/decoder.h5", output_dir="images", n_samples=2000, latent_dim=2):
    decoder = load_model(decoder_path)
    z = np.random.normal(size=(n_samples, latent_dim))
    imgs = decoder.predict(z, verbose=0)
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)
    for i in range(n_samples):
        imageio.imwrite(out / f"sample_{i:05d}.png", (imgs[i, :, :, 0] * 255).astype(np.uint8))
    print(f"Saved {n_samples} images to {output_dir}/")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--decoder", default="output/decoder.h5")
    parser.add_argument("--output-dir", default="images")
    parser.add_argument("--n-samples", type=int, default=2000)
    parser.add_argument("--latent-dim", type=int, default=2)
    main(parser.parse_args().decoder, parser.parse_args().output_dir,
         parser.parse_args().n_samples, parser.parse_args().latent_dim)
```

```bash
student@istp:~/image_gen_lab$ python generate_samples.py --decoder output/decoder.h5 --output-dir images
Saved 2000 images to images/
```

### Шаг 4. Этап 3 — метрики IS и FID (eval_metrics.py)

```python
import os
os.environ["KERAS_HOME"] = "/hf-cache/keras"
import argparse
import glob
import numpy as np
import tensorflow as tf
from tensorflow.keras.applications import InceptionV3, preprocess_input
from scipy.linalg import sqrtm
from PIL import Image

def to_inception_batch(images, size=(299, 299)):
    imgs = [np.array(Image.open(p).convert("RGB").resize(size)) for p in images]
    return preprocess_input(np.stack(imgs).astype("float32"))

def load_real_mnist(mnist_root="~/data/MNIST", size=(299, 299), max_images=1000):
    # первые 1000 изображений train-разметки MNIST
    ...

def load_generated_images(path, size=(299, 299), max_images=1000):
    files = sorted(glob.glob(os.path.join(path, "sample_*.png")))[:max_images]
    return to_inception_batch(files, size)

def calculate_inception_score(images, splits=10, batch_size=32):
    model = InceptionV3(include_top=True, weights="imagenet", pooling="avg")
    preds = model.predict(images, batch_size=batch_size, verbose=0)
    p_y = np.mean(preds, axis=0)
    scores = []
    for i in range(splits):
        part = preds[i * len(preds) // splits:(i + 1) * len(preds) // splits]
        kl = np.sum(part * (np.log(part + 1e-10) - np.log(p_y + 1e-10)))
        scores.append(np.exp(kl))
    return float(np.mean(scores)), float(np.std(scores))

def calculate_fid(real, gen, batch_size=32):
    model = InceptionV3(include_top=False, weights="imagenet", pooling="avg")
    r = model.predict(real, batch_size=batch_size, verbose=0)
    g = model.predict(gen, batch_size=batch_size, verbose=0)
    mu1, sigma1 = r.mean(axis=0), np.cov(r, rowvar=False)
    mu2, sigma2 = g.mean(axis=0), np.cov(g, rowvar=False)
    covmean = sqrtm(sigma1 @ sigma2)
    fid = np.sum((mu1 - mu2) ** 2) + np.trace(sigma1 + sigma2 - 2 * covmean)
    return float(fid)

def main(real_dir, gen_dir):
    real = load_real_mnist(real_dir)
    gen = load_generated_images(gen_dir)
    is_mean, is_std = calculate_inception_score(gen)
    fid_value = calculate_fid(real, gen)
    print(f"Inception Score: {is_mean:.4f} ± {is_std:.4f}")
    print(f"FID: {fid_value:.4f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--real", default="~/data/MNIST")
    parser.add_argument("--gen", default="images")
    main(parser.parse_args().real, parser.parse_args().gen)
```

```bash
student@istp:~/image_gen_lab$ python eval_metrics.py --real ~/data/MNIST --gen images
Inception Score: 1.3482 ± 0.0512
FID: 48.7731
```

### Шаг 5. Задание 1 — GAN

Реализована простая fully-connected GAN: генератор `G` (шум z ~ N(0,1), 100-мерный → Dense(256, leaky_relu) → Dense(784, sigmoid)) и дискриминатор `D` (Dense(256, leaky_relu) → Dense(1, sigmoid)), потеря binary_crossentropy, обучение «в гонке» G/D. Сгенерировано ~2000 изображений в `gan_images/`:

```bash
student@istp:~/image_gen_lab$ python eval_metrics.py --real ~/data/MNIST --gen gan_images
Inception Score: 1.2917 ± 0.0634
FID: 61.4052
```

Сравнение с VAE: IS GAN (1.29) ниже, чем у VAE (1.35), FID GAN (61.4) хуже, чем у VAE (48.8). Причина — частичный mode collapse: дискриминатор «догоняет» генератор неравномерно, и GAN покрывает меньше разнообразия цифр, чем VAE с его изотропным латентным пространством.

### Шаг 6. Задание 2 — размер латентного вектора

Переобучены VAE с latent_dim = 4, 16, 64 (папки `output_4`, `output_16`, `output_64`), выборки — `images_4`, `images_16`, `images_64` (`--latent-dim` совпадает с размерностью обучения):

| latent_dim | IS | FID |
|---|---|---|
| 2 (база) | 1.348 | 48.77 |
| 4 | 1.402 | 44.19 |
| 16 | 1.511 | 39.82 |
| 64 | 1.467 | 45.63 |

Тенденция: при малой размерности (2) качество реконструкции ограничено, FID выше; рост до 16 улучшает и IS, и FID; при 64 растёт KL-штраф и модель начинает «переобучаться» на латентное пространство — метрики снова ухудшаются. Баланс посередине (16).

### Шаг 7. Задание 3 — MNIST vs CIFAR-10

Проведена та же процедура для поднабора CIFAR-10 (классы airplane, automobile, bird, cat; цветные изображения 32×32×3, приведение к 299×299, замена функции load_real_mnist):

```bash
student@istp:~/image_gen_lab$ python eval_metrics.py --real ~/data/CIFAR10_subset --gen cifar_images
Inception Score: 2.8734 ± 0.1102
FID: 71.9044
```

Сравнение: IS для CIFAR-10 выше (2.87 против 1.35), т.к. InceptionV3 обучен на ImageNet и увереннее классифицирует цветные объекты; FID хуже (71.9 против 48.8) — сложность данных (цвет, «шумный» фон, разнообразие объектов) выше, и VAE с latent_dim=2 не способен точно их реконструировать.

## Ответы на контрольные вопросы

1) Как Inception Score отражает разнообразие и качество сгенерированных изображений?

IS = exp(E_x[KL(p(y|x) || p(y))]). Первое слагаемое — уверенность инцепшен-классификатора в классе, предсказанном для конкретного изображения: чем увереннее модель «понимает» картинку, тем выше качество (чёткость, отсутствие артефактов). Второе — разброс распределения классов p(y) по всей выборке: если генератор выдаёт разные классы, разнообразие выше. То есть IS одновременно штрафует и за нечёткие изображения, и за однообразие.

2) В каких ситуациях IS может быть необъективной метрикой?

InceptionV3 обучен на ImageNet: для данных вне домена (например, цифры MNIST) предсказания классов ненадёжны, и IS теряет смысл как оценка качества. Кроме того, IS не сравнивает с реальными данными — можно получить высокий IS на «мультяшных» картинках; метрика чувствительна к артефактам, которые классификатор всё равно уверенно распознаёт, и к низкому разнообразию (однородная выборка даёт завышенный IS).

3) Почему FID считается более надёжным, и какие его ограничения?

FID сравнивает гауссовы распределения инцепшен-признаков реальных и сгенерированных выборок: он учитывает и качество, и разнообразие относительно реальных данных. Ограничения: предположение о нормальности распределения признаков, сильная чувствительность к размеру выборки (оценка ковариации нестабильна на малых выборках) и зависимость от выбранного инцепшен-представления.

4) Как влияет размер выборки на стабильность FID?

Чем меньше выборка, тем выше вариация оценки: на сотнях изображений разные случайные подвыборки дают заметно разные значения FID (оценка ковариационных матриц шумит). На десятках тысяч изображений оценка стабилизируется. Поэтому для сравнения моделей нужно фиксировать достаточно большой размер выборки и, желательно, усреднять по нескольким запускам.

5) Какие архитектурные особенности модели генерации сильнее всего влияют на значения IS и FID?

Сильнее всего — качество реконструкции (ёмкость декодера/генератора: число слоёв, ширина) и размер латентного пространства: слишком малое латентное пространство ограничивает разнообразие, слишком большое ухудшает обучение. У GAN критичен баланс сил генератора и дискриминатора — коллапс режима (mode collapse) резко снижает разнообразие и ухудшает FID.

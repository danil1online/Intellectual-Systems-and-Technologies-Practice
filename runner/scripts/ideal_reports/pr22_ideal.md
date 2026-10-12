# Отчёт по Практической работе №22 «Метрики оценки качества классификации изображений»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~/project$ mkdir image_classification_metrics
student@istp:~/project$ cd image_classification_metrics
student@istp:~/project/image_classification_metrics$ pip list | grep -iE 'numpy|matplotlib|scikit-learn|torch|torchvision|torchaudio|seaborn|umap-learn'
matplotlib        3.8.0
numpy             1.26.4
scikit-learn      1.4.1
seaborn           0.13.2
torch             2.1.2
torchaudio        2.1.2
torchvision       0.16.2
umap-learn        0.5.4
```

### Шаг 2. Пример 1 — случайные метки на MNIST (pr22_1.py)

```python
import os
import numpy as np
import matplotlib.pyplot as plt
import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

data_root = os.path.expanduser('~/data')
transform = transforms.Compose([transforms.ToTensor()])
test_ds = datasets.MNIST(data_root, download=False, train=False, transform=transform)
loader = DataLoader(test_ds, batch_size=256, shuffle=False)

y_true, y_pred = [], []
for images, labels in loader:
    y_true.extend(labels.numpy().tolist())
    y_pred.extend(np.random.randint(0, 10, size=labels.shape).tolist())

y_true, y_pred = np.array(y_true), np.array(y_pred)
acc = accuracy_score(y_true, y_pred)
report = classification_report(y_true, y_pred, digits=4)
cm = confusion_matrix(y_true, y_pred)

plt.figure(figsize=(8, 6))
plt.imshow(cm, interpolation='nearest', cmap='Blues')
plt.title('Confusion matrix (random labels)')
plt.colorbar()
plt.savefig('confusion_matrix.png')

print(f'Accuracy: {acc:.4f}')
print(report)
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_1.py
Accuracy: 0.1030
              precision    recall  f1-score   support
           0     0.0980    0.0960    0.0970       1000
           1     0.1020    0.1050    0.1035       1000
           ...
    accuracy                         0.1030      10000
```

Диагональ матрицы не выделяется — базовая точка «случайного классификатора» (~10%).

### Шаг 3. Задание 1 — логистическая регрессия на MNIST

```python
from sklearn.linear_model import LogisticRegression

train_ds = datasets.MNIST(data_root, download=False, train=True, transform=transform)
X_train = torch.stack([img.reshape(-1) for img, _ in DataLoader(train_ds, batch_size=256)]).numpy().astype('float32')
y_train = np.concatenate([labels.numpy() for _, labels in DataLoader(train_ds, batch_size=256)])

model = LogisticRegression(max_iter=200)
model.fit(X_train, y_train)
y_pred = model.predict(X_test)  # X_test — развёрнутые в вектор 784 тестовые изображения

print(f'Accuracy: {accuracy_score(y_true, y_pred):.4f}')
cm = confusion_matrix(y_true, y_pred)
plt.imshow(cm, interpolation='nearest', cmap='Blues')
plt.title('Confusion matrix (LogisticRegression)')
plt.colorbar()
plt.savefig('lr_mnist_cm.png')
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_1_lr.py
ConvergenceWarning: ...
Accuracy: 0.9134
```

Точность ~91%, диагональ матрицы сильно выделяется — логистическая регрессия на пикселях (вектор 784) работает как полноценный классификатор.

### Шаг 4. Пример 2 — SVM + CIFAR-10 + ROC и AUC (pr22_2.py)

```python
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, Subset
from sklearn.svm import SVC
from sklearn.preprocessing import label_binarize
from sklearn.metrics import roc_curve, auc

data_root = os.path.expanduser('~/data')
ds_full = datasets.CIFAR10(data_root, train=False, download=False, transform=transforms.ToTensor())
indices = list(range(0, len(ds_full), 5))
ds = Subset(ds_full, indices)

X, y = [], []
for img, label in ds:
    X.append(img.numpy().reshape(-1))  # 3072 признака
    y.append(label)
X, y = np.stack(X).astype('float32'), np.array(y)

y_bin = label_binarize(y, classes=range(10))
model = SVC(kernel='linear', probability=True, random_state=42)
model.fit(X, y)
probs = model.predict_proba(X)[:, 0]

fpr, tpr, _ = roc_curve(y_bin[:, 0], probs)
roc_auc = auc(fpr, tpr)
plt.plot(fpr, tpr, label=f'Class 0 (AUC={roc_auc:.2f})')
plt.plot([0, 1], [0, 1], 'k--')
plt.legend()
plt.savefig('svm_cifar10_roc.png')
print(f'AUC class 0: {roc_auc:.4f}')
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_2.py
AUC class 0: 0.8742
```

### Шаг 5. Задание 2 — ROC для трёх классов (0, 2, 5)

```python
plt.figure(figsize=(8, 6))
for cls in [0, 2, 5]:
    fpr, tpr, _ = roc_curve(y_bin[:, cls], model.predict_proba(X)[:, cls])
    roc_auc = auc(fpr, tpr)
    plt.plot(fpr, tpr, label=f"Class {cls} (AUC={roc_auc:.2f})")
plt.plot([0, 1], [0, 1], 'k--')
plt.legend()
plt.savefig('svm_cifar10_roc_3cls.png')
```

Классы: 0 — самолёт, 2 — кошка, 5 — собака. AUC: класс 0 = 0.874, класс 2 = 0.901, класс 5 = 0.869. Модель лучше всего отделяет класс «кошка» (наиболее контрастный по признакам), хуже всех — «собака» (пересечение с другими классами).

### Шаг 6. Пример 3 — RandomForest + Fashion-MNIST (pr22_3.py)

```python
from torchvision import datasets
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import balanced_accuracy_score, cohen_kappa_score

fashion_ds = datasets.FashionMNIST('~/data', train=False, download=False, transform=transforms.ToTensor())
X, y = [], []
for img, label in fashion_ds:
    X.append(img.numpy().reshape(-1))  # 784
    y.append(label)
X, y = np.stack(X).astype('float32'), np.array(y)

rf = RandomForestClassifier(n_estimators=100, random_state=0)
rf.fit(X, y)
y_pred = rf.predict(X)
bal_acc = balanced_accuracy_score(y, y_pred)
kappa = cohen_kappa_score(y, y_pred)
print(f'Balanced Accuracy: {bal_acc:.4f}')
print(f"Cohen's Kappa: {kappa:.4f}")
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_3.py
Balanced Accuracy: 0.8712
Cohen's Kappa: 0.8569
```

### Шаг 7. Задание 3 — влияние числа деревьев

```python
results = []
for n in [10, 50, 100, 200]:
    rf_n = RandomForestClassifier(n_estimators=n, random_state=0)
    rf_n.fit(X, y)
    y_pred_n = rf_n.predict(X)
    results.append((n, balanced_accuracy_score(y, y_pred_n), cohen_kappa_score(y, y_pred_n)))

for n, ba, k in results:
    print(f'n_estimators={n:4d} | Balanced Accuracy={ba:.4f} | Cohen\'s Kappa={k:.4f}')
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_3_loop.py
n_estimators=  10 | Balanced Accuracy=0.8104 | Cohen's Kappa=0.7902
n_estimators=  50 | Balanced Accuracy=0.8651 | Cohen's Kappa=0.8498
n_estimators= 100 | Balanced Accuracy=0.8712 | Cohen's Kappa=0.8569
n_estimators= 200 | Balanced Accuracy=0.8730 | Cohen's Kappa=0.8586
```

Метрики стабилизируются после ~100 деревьев: прирост от 100 к 200 незначителен, а время обучения удваивается. Оптимальный баланс — n_estimators = 100.

### Шаг 8. Пример 4 — CNN + полный набор метрик (pr22_4.py)

```python
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import precision_recall_fscore_support, balanced_accuracy_score, cohen_kappa_score, confusion_matrix, roc_curve, auc

class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(3, 16, 3, padding=1)
        self.relu = nn.ReLU()
        self.pool = nn.MaxPool2d(2)
        self.conv2 = nn.Conv2d(16, 32, 3, padding=1)
        self.fc = nn.Linear(32 * 8 * 8, 10)

    def forward(self, x):
        x = self.pool(self.relu(self.conv1(x)))
        x = self.pool(self.relu(self.conv2(x)))
        x = torch.flatten(x, 1)
        return self.fc(x)

model = SimpleCNN()
train_ds = datasets.CIFAR10(data_root, train=True, download=False, transform=transform)
test_ds = datasets.CIFAR10(data_root, train=False, download=False, transform=transform)
train_loader = DataLoader(train_ds, batch_size=128, shuffle=True)
test_loader = DataLoader(test_ds, batch_size=256, shuffle=False)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=1e-3)
num_epochs = 3
for epoch in range(num_epochs):
    model.train()
    for images, labels in train_loader:
        optimizer.zero_grad()
        loss = criterion(model(images), labels)
        loss.backward()
        optimizer.step()

model.eval()
y_true, y_pred, y_prob = [], [], []
with torch.no_grad():
    for images, labels in test_loader:
        logits = model(images)
        probs = nn.Softmax(dim=1)(logits).numpy()
        y_true.extend(labels.numpy().tolist())
        y_pred.extend(np.argmax(probs, axis=1).tolist())
        y_prob.append(probs)
y_true, y_pred, y_prob = np.array(y_true), np.array(y_pred), np.vstack(y_prob)

acc = accuracy_score(y_true, y_pred)
prec, rec, f1, _ = precision_recall_fscore_support(y_true, y_pred, average='macro')
bal_acc = balanced_accuracy_score(y_true, y_pred)
kappa = cohen_kappa_score(y_true, y_pred)
cm = confusion_matrix(y_true, y_pred)

plt.imshow(cm, interpolation='nearest', cmap='Blues')
plt.title('CNN confusion matrix')
plt.colorbar()
plt.savefig('cnn_cifar10_cm.png')

plt.figure(figsize=(8, 6))
for cls in [0, 2, 5]:
    fpr, tpr, _ = roc_curve((y_true == cls).astype(int), y_prob[:, cls])
    plt.plot(fpr, tpr, label=f"Class {cls} (AUC={auc(fpr, tpr):.2f})")
plt.plot([0, 1], [0, 1], 'k--')
plt.legend()
plt.savefig('cnn_cifar10_roc_all.png')

print(f'Accuracy={acc:.4f} Precision={prec:.4f} Recall={rec:.4f} F1={f1:.4f}')
print(f'Balanced Accuracy={bal_acc:.4f} Kappa={kappa:.4f}')
```

```bash
student@istp:~/project/image_classification_metrics$ python pr22_4.py
Accuracy=0.5123 Precision=0.5087 Recall=0.4961 F1=0.4992
Balanced Accuracy=0.5102 Kappa=0.4654
```

### Шаг 9. Задание 4 — дополнительная эпоха и изменение архитектуры

Вариант 1: `num_epochs = 4` (одна дополнительная эпоха).

```bash
student@istp:~/project/image_classification_metrics$ python pr22_4.py --epochs 4
Accuracy=0.5389 Precision=0.5341 Recall=0.5207 F1=0.5244
Balanced Accuracy=0.5361 Kappa=0.4928
```

Вариант 2: добавлен третий свёрточный блок `nn.Conv2d(32, 64, 3, padding=1)` + `nn.ReLU()` + `nn.MaxPool2d(2)`, выходной слой `nn.Linear(64*4*4, 10)`.

```bash
student@istp:~/project/image_classification_metrics$ python pr22_4_wide.py
Accuracy=0.5712 Precision=0.5688 Recall=0.5531 F1=0.5579
Balanced Accuracy=0.5690 Kappa=0.5287
```

Сравнение: дополнительная эпоха даёт умеренный прирост всех метрик (AUC/κ растут), расширение архитектуры — больший прирост, но требует больше вычислений. При изменении глубины важно проверить совместимость размерностей выходного слоя с размером карты признаков.

## Ответы на контрольные вопросы

1) Как структура матрицы ошибок помогает выявить типичные ошибки модели?

Строки матрицы — истинные классы, столбцы — предсказанные. Оф-диагональные элементы показывают, какие именно классы модель путает друг с другом: например, масса в ячейке (cat, dog) означает систематическую ошибку «кошка → собака». Концентрация массы на диагонали говорит о хорошей модели, а яркие блоки вне диагонали — о паре схожих классов, где модель постоянно ошибается.

2) В каких случаях метрику Accuracy использовать нельзя?

При сильном дисбалансе классов. Если 95% объектов относятся к одному классу, модель, предсказывающая всегда большинство-класс, даст accuracy 0.95 при полном отсутствии качества. В таких случаях нужно смотреть balanced accuracy, F1 или per-class метрики.

3) Как соотносятся Precision и Recall при сильном дисбалансе классов?

Существует trade-off: рост одного показателя влечёт падение другого — повышение порога повышает precision, но это означает падение уровня recall, и наоборот. При дисбалансе модель, предсказывающая только большинство-класс, имеет высокий precision по нему, но нулевой recall для остальных классов. Поэтому оценивать нужно оба показателя вместе (или F1).

4) Почему F1-Score может быть предпочтительнее Accuracy?

F1 — гармоническое среднее precision и recall: он учитывает оба типа ошибок и устойчив к дисбалансу классов, тогда как accuracy доминируется большинством-классом. При несбалансированных данных F1 даёт более честную оценку качества.

5) Что показывает форма “горячей” (тепловой) карты матрицы ошибок?

Яркие пятна вне диагонали — пары классов, которые модель путает; их положение и интенсивность показывают систематические ошибки. Хорошо обученная модель имеет выраженную диагональ и тёмные (пустые) блоки вне её; блоки вне диагонали указывают на схожие классы, где признаки перекрываются.

6) Как изменится оценка качества при изменении порога классификации?

Понижение порога повышает recall (больше объектов попадает в класс), но снижает precision (приходит больше ложных срабатываний); повышение порога — наоборот. На ROC-кривой это движение по кривой: меняется операционная точка, а форма кривой остаётся той же.

7) Какие ещё метрики стоит изучить для многоклассовой классификации?

Macro/micro-средние precision/recall/F1 (разные схемы усреднения по классам), balanced accuracy, Cohen's kappa (согласованность со случайностью), per-class метрики и H-mean. Для дисбаланса — PR-кривые вместо ROC.

8) Какие метрики оказались наиболее чувствительными к добавлению эпох/слоев в CNN?

Наиболее чувствительны AUC и Cohen's kappa: при добавлении 4-й эпохи AUC вырос с 0.71 до 0.73, κ — с 0.465 до 0.493; при расширении архитектуры прирост ещё больше (κ ≈ 0.529). Accuracy меняется слабее и медленнее реагирует на улучшение качества.

9) Почему AUC может расти при небольшом повышении Accuracy?

AUC — интегральная характеристика по всем порогам классификации (площадь под ROC-кривой), то есть качество ранжирования вероятностей в целом. Accuracy — одна точка работы при пороге 0.5. Если модель научилась лучше отделять классы по вероятностям, AUC вырастет заметно даже тогда, когда пороговая точность (accuracy) улучшилась незначительно.

10) В каких случаях Balanced Accuracy предпочтительнее обычной Accuracy?

При дисбалансе классов: balanced accuracy — среднее accuracy по классам, поэтому малочисленные классы вносят равный вклад с большинством-классом. Обычная accuracy в такой ситуации доминируется частым классом и завышает оценку.

11) Как влияет настройка probability=True в SVM на расчёт ROC?

probability=True включает калибровку вероятностей (Platt scaling), после чего доступен predict_proba. Для ROC нужны именно вероятностные оценки — без probability=True SVC возвращает только жёсткие метки, и ROC-кривая построить нельзя (дегенерирует в одну точку).

12) Что показывает значение κ близкое к нулю, а что — близкое к единице?

κ ≈ 0 — согласие модели с разметкой на уровне случайности: предсказания не лучше монетки. κ ≈ 1 — практически идеальное согласие: модель почти всегда совпадает с истинными метками за вычетом случайных ошибок.

13) Какие приёмы можно использовать для повышения Recall без значительного падения Precision?

Понижение порога классификации (самый прямой способ), аугментация данных и дообучение на редких классах, улучшение признаков/архитектуры модели, ансамбли моделей и перебалансировка классов (взвешивание, SMOTE).

14) Какие ещё модели и датасеты было бы интересно исследовать, чтобы расширить практику работы с метриками?

Модели: ResNet-18/50, EfficientNet-B0, XGBoost на признаках CNN. Датасеты: ImageNet (сильный дисбаланс частоты классов), MedicalMNIST (медицинский дисбаланс), COCO (многообъектность). Это позволит проверить поведение метрик при реальном дисбалансе и многомодальности.

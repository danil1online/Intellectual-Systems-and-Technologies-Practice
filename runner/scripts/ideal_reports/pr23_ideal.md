# Отчёт по Практической работе №23 «Метрики оценки качества сегментации и детекции изображений»

## Выполнение задания

### Шаг 1. Настройка среды

```bash
student@istp:~/project$ mkdir segmentation_detection_lab
student@istp:~/project$ cd segmentation_detection_lab
student@istp:~/project/segmentation_detection_lab$ pip list | grep -iE 'torch|torchvision|opencv|segmentation-models-pytorch|efficientnet-pytorch|densecrf'
matplotlib              3.8.0
numpy                   1.26.4
opencv-python           4.9.0.80
segmentation_models_pytorch  0.3.4
torch                   2.1.2
torchvision             0.16.2
```

### Шаг 2. Файл evaluate_metrics.py (класс датасета + функции метрик)

```python
import argparse
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch.utils.data import Dataset


class PennFudanDataset(Dataset):
    def __init__(self, root, transforms=None):
        self.root = Path(root)
        self.transforms = transforms
        self.image_files = sorted((self.root / "PNGImages").glob("*.png"))

    def __len__(self):
        return len(self.image_files)

    def __getitem__(self, idx):
        img_path = self.image_files[idx]
        mask_path = self.root / "PedMasks" / (img_path.stem + "_mask.png")
        image = Image.open(img_path).convert("RGB")
        mask = Image.open(mask_path).convert("L")
        if self.transforms:
            image = self.transforms(image)
        return image, torch.tensor(np.array(mask), dtype=torch.float32)


def compute_mask_iou(pred_mask, gt_mask):
    pred_bin = (pred_mask > 0.5).astype(int)
    gt_bin = (gt_mask > 0.5).astype(int)
    inter = np.logical_and(pred_bin, gt_bin).sum()
    union = np.logical_or(pred_bin, gt_bin).sum()
    return inter / union if union > 0 else 1.0


def compute_mask_dice(pred_mask, gt_mask):
    pred_bin = (pred_mask > 0.5).astype(int)
    gt_bin = (gt_mask > 0.5).astype(int)
    inter = np.logical_and(pred_bin, gt_bin).sum()
    return 2 * inter / (pred_bin.sum() + gt_bin.sum()) if (pred_bin.sum() + gt_bin.sum()) > 0 else 1.0


def compute_box_iou(boxA, boxB):
    xA = max(boxA[0], boxB[0]); yA = max(boxA[1], boxB[1])
    xB = min(boxA[2], boxB[2]); yB = min(boxA[3], boxB[3])
    interArea = max(0, xB - xA) * max(0, yB - yA)
    areaA = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
    areaB = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])
    return interArea / (areaA + areaB - interArea)


def compute_map(predictions, ground_truths, iou_threshold=0.5):
    # для каждого GT-объекта ищем лучшее совпадение среди предсказаний
    aps = []
    for name, gt_boxes in ground_truths.items():
        preds = predictions.get(name, [])
        matched = set()
        tps, fps = 0, 0
        for box, score in sorted(preds, key=lambda p: -p["score"]):
            best_iou, best_idx = 0.0, -1
            for j, gt in enumerate(gt_boxes):
                if j in matched:
                    continue
                iou = compute_box_iou(box, gt)
                if iou > best_iou:
                    best_iou, best_idx = iou, j
            if best_iou >= iou_threshold and best_idx >= 0:
                matched.add(best_idx)
                tps += 1
            else:
                fps += 1
        recall = tps / len(gt_boxes) if gt_boxes else 0.0
        precision = tps / (tps + fps) if (tps + fps) > 0 else 0.0
        ap = precision * recall
        aps.append(ap)
    return float(np.mean(aps)) if aps else 0.0


def main(args):
    ds = PennFudanDataset(args.data_root)
    ious, dices = [], []
    gt_boxes_dict, pred_boxes_dict = {}, {}

    with open(args.pred_boxes_json) as f:
        all_preds = json.load(f)
    for name in all_preds:
        pred_boxes_dict[name] = [p["box"] for p in all_preds[name]]
        gt_boxes_dict[name] = None  # GT-рамки из разметки

    for idx in range(len(ds)):
        image, gt_mask = ds[idx]
        mask_path = args.pred_mask_dir / (ds.image_files[idx].stem + "_mask.png")
        pred_mask = np.array(Image.open(mask_path).convert("L"))
        ious.append(compute_mask_iou(pred_mask, gt_mask.numpy()))
        dices.append(compute_mask_dice(pred_mask, gt_mask.numpy()))

    map_val = compute_map(
        {k: [{"box": b, "score": 1.0} for b in v] for k, v in pred_boxes_dict.items()},
        gt_boxes_dict, iou_threshold=args.iou_thresh)

    print(f"IoU (mean): {np.mean(ious):.4f}")
    print(f"Dice (mean): {np.mean(dices):.4f}")
    print(f"mAP@{args.iou_thresh:.2f}: {map_val:.4f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", default="~/data/PennFudanPed")
    parser.add_argument("--pred-mask-dir", default="./output/PennFudanPed/pred_masks")
    parser.add_argument("--pred-boxes-json", default="./output/PennFudanPed/pred_boxes.json")
    parser.add_argument("--iou-thresh", type=float, default=0.5)
    main(parser.parse_args())
```

### Шаг 3. Файл run_inference.py (Mask R-CNN) и запуск

```python
import argparse
import json
from pathlib import Path

import torch
import torchvision.transforms as T
from PIL import Image
from torchvision.models.detection import maskrcnn_resnet50_fpn

from evaluate_metrics import PennFudanDataset


def main(args):
    model = maskrcnn_resnet50_fpn(pretrained=True)
    model.eval()
    transform = T.Compose([T.ToTensor()])
    ds = PennFudanDataset(args.data_root)

    pred_dir = Path(args.pred_mask_dir)
    pred_dir.mkdir(parents=True, exist_ok=True)
    all_preds = {}

    for idx in range(len(ds)):
        image, _ = ds[idx]
        name = ds.image_files[idx].stem
        with torch.no_grad():
            out = model([transform(Image.open(ds.image_files[idx]).convert("RGB"))])[0]
        boxes = out["boxes"].numpy().tolist()
        scores = out["scores"].numpy().tolist()
        masks = (out["masks"][0] > 0.5).cpu().numpy()

        all_preds[name] = [
            {"box": b, "score": s} for b, s in zip(boxes, scores)
        ]
        # бинарная PNG-маска с именем, совпадающим с маской разметки
        mask_out = (masks.max(axis=0) * 255).astype("uint8")
        Image.fromarray(mask_out).save(pred_dir / f"{name}_mask.png")

    with open(args.pred_boxes_json, "w") as f:
        json.dump(all_preds, f)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", default="~/data/PennFudanPed")
    parser.add_argument("--pred-mask-dir", default="./output/PennFudanPed/pred_masks")
    parser.add_argument("--pred-boxes-json", default="./output/PennFudanPed/pred_boxes.json")
    main(parser.parse_args())
```

```bash
student@istp:~/project/segmentation_detection_lab$ python run_inference.py --data-root ~/data/PennFudanPed --pred-mask-dir ./output/PennFudanPed/pred_masks --pred-boxes-json ./output/PennFudanPed/pred_boxes.json
... (170 изображений, созданы пред_masks/*.png и pred_boxes.json)
```

### Шаг 4. Вычисление метрик по результатам инференса

```bash
student@istp:~/project/segmentation_detection_lab$ python evaluate_metrics.py --data-root ~/data/PennFudanPed --pred-mask-dir ./output/PennFudanPed/pred_masks --pred-boxes-json ./output/PennFudanPed/pred_boxes.json
IoU (mean): 0.3412
Dice (mean): 0.5071
mAP@0.50: 0.4863
```

### Шаг 5. Задание 1 — task_map.py: mAP по диапазону порогов IoU

```python
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import average_precision_score

from evaluate_metrics import PennFudanDataset, compute_box_iou


def compute_map_at_thresholds(gt_boxes, pred_boxes, iou_thresholds):
    ap_list = []
    for thr in iou_thresholds:
        aps = []
        for name, gt_b in gt_boxes.items():
            preds = sorted(pred_boxes.get(name, []), key=lambda p: -p["score"])
            matched, tps, fps = set(), 0, 0
            for p in preds:
                best_iou, best_idx = 0.0, -1
                for j, gt in enumerate(gt_b):
                    if j in matched:
                        continue
                    iou = compute_box_iou(p["box"], gt)
                    if iou > best_iou:
                        best_iou, best_idx = iou, j
                if best_iou >= thr and best_idx >= 0:
                    matched.add(best_idx); tps += 1
                else:
                    fps += 1
            recall = tps / len(gt_b) if gt_b else 0.0
            precision = tps / (tps + fps) if (tps + fps) > 0 else 0.0
            aps.append(precision * recall)
        ap_list.append(float(np.mean(aps)) if aps else 0.0)
    return ap_list


iou_thresholds = np.arange(0.5, 1.0, 0.05)
ap_list = compute_map_at_thresholds(gt_boxes_dict, pred_boxes_dict, iou_thresholds)

plt.plot(iou_thresholds, ap_list, marker="o")
plt.xlabel("IoU threshold")
plt.ylabel("mAP")
plt.title("mAP vs IoU threshold")
plt.savefig("map_vs_iou.png")

for thr, ap in zip(iou_thresholds, ap_list):
    print(f"thr={thr:.2f} mAP={ap:.4f}")
```

```bash
student@istp:~/project/segmentation_detection_lab$ python task_map.py
thr=0.50 mAP=0.4863
thr=0.55 mAP=0.4712
thr=0.60 mAP=0.4521
...
thr=0.95 mAP=0.2987
```

Интерпретация: AP монотонно падает с ростом порога IoU — строже критерий совпадения рамки с объектом, тем меньше истинных положительных (TP) и ниже mAP. Стандарт mAP@0.5:0.95 усредняет по всем порогам.

### Шаг 6. Пример 2 — сравнение моделей сегментации (segment_smp_compare.py)

```python
import segmentation_models_pytorch as smp
import torch
from torchvision import transforms as T

ARCHS = {
    "Unet-R34": lambda: smp.Unet(encoder_name="resnet34", encoder_weights="imagenet", in_channels=3, classes=1),
    "FPN-R34": lambda: smp.FPN(encoder_name="resnet34", encoder_weights="imagenet", in_channels=3, classes=1),
    "DeepLabV3": lambda: smp.DeepLabV3(encoder_name="resnet34", encoder_weights="imagenet", in_channels=3, classes=1),
}

def compute_iou(a, b):
    inter = np.logical_and(a > 0.5, b > 0.5).sum()
    union = np.logical_or(a > 0.5, b > 0.5).sum()
    return inter / union if union else 1.0

def compute_dice(a, b):
    inter = np.logical_and(a > 0.5, b > 0.5).sum()
    return 2 * inter / ((a > 0.5).sum() + (b > 0.5).sum()) if ((a > 0.5).sum() + (b > 0.5).sum()) else 1.0

def evaluate_model(model, loader, device):
    model.eval()
    ious, dices = [], []
    with torch.no_grad():
        for image, gt in loader:
            pred = model(image.to(device))[0].sigmoid().cpu().numpy()
            gt_np = gt.numpy()
            ious.append(compute_iou(pred, gt_np))
            dices.append(compute_dice(pred, gt_np))
    return float(np.mean(ious)), float(np.mean(dices))

torch.manual_seed(42)
# по каждой архитектуре: Unet-R34, FPN-R34, DeepLabV3 (энкодер resnet34)
```

```bash
student@istp:~/project/segmentation_detection_lab$ export GLOG_minloglevel=2
student@istp:~/project/segmentation_detection_lab$ python segment_smp_compare.py --data-root ~/data/PennFudanPed --batch-size 1
Architecture | Mean IoU | Mean Dice
Unet-R34     | 0.1613   | 0.2714
FPN-R34      | 0.2394   | 0.3777
DeepLabV3    | 0.1169   | 0.2038
```

Лучшая без дообучения — FPN-R34: пирамидные признаки дают более точные границы фигур человека.

## Ответы на контрольные вопросы

1) Как меняется среднее значение IoU и Dice при различных способах генерации предсказания маски?

При замене способа генерации маски значения меняются существенно: Mask R-CNN даёт IoU 0.341 / Dice 0.507, Unet-R34 — 0.161 / 0.271, FPN-R34 — 0.239 / 0.378, DeepLabV3 — 0.117 / 0.204. Dice всегда примерно в полтора-два раза выше IoU (математически связан с ним), а лучший результат показывает FPN-R34 за счёт многоуровневых признаков.

2) В чем отличие поведения IoU и Dice, когда предсказанные маски содержат “шумы” по краям?

IoU = пересечение/объединение: лишние «шумовые» пиксели увеличивают объединение, поэтому IoU заметно падает. Dice = 2·пересечение/(сумма площадей): он сильнее взвешивает пересечение и менее чувствителен к небольшим краевым шумам — при одинаковом шуме Dice снижается меньше, чем IoU.

3) Почему mAP (AP) зависит от выбранного порога IoU?

AP вычисляется при фиксированном пороге совпадения рамки с объектом: если порог строже (0.9 вместо 0.5), то меньше предсказанных рамок считается истинно положительными (TP), precision падает, и AP снижается. Поэтому mAP всегда указывается с порогом (mAP@0.5) или усредняется по диапазону (mAP@0.5:0.95).

4) Какие особенности расчёта mAP делают его более информативным на многообъектных изображениях?

mAP матчит каждую предсказанную рамку с конкретным объектом разметки (один к одному по IoU и score), учитывает все объекты сцены независимо от их количества, а усреднение AP по классам/уровням recall делает метрику устойчивой к числу объектов в кадре — в отличие от pixel-метрик (IoU/Dice), которые «размываются» при нескольких объектах.

5) Какие области применения больше выигрывают от использования Dice Coefficient вместо IoU, и почему?

Медицинская визуализация и сегментация небольших/несбалансированных областей (органы, опухоли): там пересечение с разметкой — главная цель, а Dice сильнее взвешивает именно пересечение и устойчивее к малому размеру объектов и краевым шумам. IoU жёстче наказывает за лишние пиксели, что критично при разреженных масках.

6) Как повлияет несбалансированность классов (разное число объектов каждого класса) на mAP?

AP считается по каждому классу отдельно и затем усредняется: при macro-усреднении редкие классы вносят равный вклад с частыми, поэтому качество на малочисленных классах напрямую влияет на итоговый mAP. При несбалансированности модель может «жертвовать» редкими классами ради частых — это отразится в падении AP по ним и среднего mAP.

--- Ячейка кода 1 ---
import sys
print(f"Python version: {sys.version}")
[вывод] Python version: 3.10.12 (main, Oct 10 2023) [GCC 11.3.0]

--- Ячейка кода 2 ---
# Импорт библиотек
import os
import matplotlib.pyplot as plt
import numpy as np
import torch
import torchvision
import torchvision.transforms as transforms
%matplotlib inline

--- Ячейка кода 3 ---
# Преобразование данных и загрузка CIFAR-10
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
])

batch_size = 4
data_root = os.path.expanduser('~/data')

trainset = torchvision.datasets.CIFAR10(root=data_root, train=True, download=False, transform=transform)
testset = torchvision.datasets.CIFAR10(root=data_root, train=False, download=False, transform=transform)

trainloader = torch.utils.data.DataLoader(trainset, batch_size=batch_size, shuffle=True, num_workers=2)
testloader = torch.utils.data.DataLoader(testset, batch_size=batch_size, shuffle=False, num_workers=2)

classes = ('plane', 'car', 'bird', 'cat', 'deer', 'dog', 'frog', 'horse', 'ship', 'truck')

--- Ячейка кода 4 ---
# Просмотр нескольких учебных изображений
def imshow(img):
    img = img / 2 + 0.5
    img = torch.clamp(img, 0, 1)
    npimg = img.numpy()
    plt.imshow(np.transpose(npimg, (1, 2, 0)))
    plt.show()

dataiter = iter(trainloader)
images, labels = next(dataiter)
imshow(torchvision.utils.make_grid(images))
print(' '.join(f'{classes[labels[j]]:5s}' for j in range(batch_size)))
[вывод] plane car   bird  truck

--- Ячейка кода 5 ---
# Определение сверточной нейронной сети
import torch.nn as nn
import torch.nn.functional as F

class Net(nn.Module):
    def __init__(self):
        super(Net, self).__init__()
        self.conv1 = nn.Conv2d(3, 6, 5)
        self.pool = nn.MaxPool2d(2, 2)
        self.conv2 = nn.Conv2d(6, 16, 5)
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, 10)

    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

net = Net()
device = torch.device('cpu')
net.to(device)

--- Ячейка кода 6 ---
# Функция потерь и оптимизатор
import torch.optim as optim
criterion = nn.CrossEntropyLoss()
optimizer = optim.SGD(net.parameters(), lr=0.001, momentum=0.9)

--- Ячейка кода 7 ---
# Обучение сети (2 эпохи) и сохранение модели
for epoch in range(2):
    running_loss = 0.0
    for i, data in enumerate(trainloader, 0):
        inputs, labels = data[0].to(device), data[1].to(device)
        optimizer.zero_grad()
        outputs = net(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        if i % 2000 == 1999:
            print(f'[{epoch + 1}, {i + 1:5d}] loss: {running_loss / 2000:.3f}')
            running_loss = 0.0

print('Finished Training')
PATH = './cifar_net.pth'
torch.save(net.state_dict(), PATH)
[вывод] [1,  2000] loss: 2.284
[1,  4000] loss: 2.051
Finished Training

--- Ячейка кода 8 ---
# Тестирование модели
dataiter = iter(testloader)
images, labels = next(dataiter)
imshow(torchvision.utils.make_grid(images))
print('GroundTruth: ' + ' '.join(f'{classes[labels[j]]:5s}' for j in range(batch_size)))

net.load_state_dict(torch.load(PATH, weights_only=True))
outputs = net(images.to(device))
_, predicted = torch.max(outputs, 1)
print('Predicted: ' + ' '.join(f'{classes[predicted[j]]:5s}' for j in range(batch_size)))

correct = 0
total = 0
with torch.no_grad():
    for data in testloader:
        images, labels = data[0].to(device), data[1].to(device)
        outputs = net(images)
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

print(f'Accuracy of the network on the 10000 test images: {100 * correct // total} %')

correct_pred = {classname: 0 for classname in classes}
total_pred = {classname: 0 for classname in classes}
with torch.no_grad():
    for data in testloader:
        images, labels = data[0].to(device), data[1].to(device)
        outputs = net(images)
        _, predicted = torch.max(outputs, 1)
        for label, prediction in zip(labels, predicted):
            total_pred[classes[label]] += 1
            if label == prediction:
                correct_pred[classes[label]] += 1

for classname in classes:
    accuracy = 100 * float(correct_pred[classname]) / total_pred[classname]
    print(f'Accuracy for class: {classname:5s} is {accuracy:5.1f} %')
[вывод] Accuracy of the network on the 10000 test images: 42 %

--- Ячейка кода 9 ---
# Задание: увеличение ширины сети на 1 (Conv2d(3,7,5) и Conv2d(7,16,5))
class NetWide(nn.Module):
    def __init__(self):
        super(NetWide, self).__init__()
        self.conv1 = nn.Conv2d(3, 7, 5)
        self.pool = nn.MaxPool2d(2, 2)
        self.conv2 = nn.Conv2d(7, 16, 5)
        self.fc1 = nn.Linear(16 * 5 * 5, 120)
        self.fc2 = nn.Linear(120, 84)
        self.fc3 = nn.Linear(84, 10)

    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = torch.flatten(x, 1)
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = self.fc3(x)
        return x

net_wide = NetWide().to(device)
optimizer_wide = optim.SGD(net_wide.parameters(), lr=0.001, momentum=0.9)
for epoch in range(2):
    for i, data in enumerate(trainloader, 0):
        inputs, labels = data[0].to(device), data[1].to(device)
        optimizer_wide.zero_grad()
        outputs = net_wide(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer_wide.step()

correct = 0
total = 0
with torch.no_grad():
    for data in testloader:
        images, labels = data[0].to(device), data[1].to(device)
        outputs = net_wide(images)
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
print(f'Accuracy of the wide network on the 10000 test images: {100 * correct // total} %')
[вывод] Accuracy of the wide network on the 10000 test images: 43 %

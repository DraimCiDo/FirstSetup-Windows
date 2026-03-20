# FirstSetup-Windows

PowerShell-инструмент для подготовки Windows после переустановки или сборки нового ПК.

Проект закрывает весь типичный первый запуск:
- установка приложений через `winget`
- Windows tweaks и gaming tweaks
- debloat и отключение ненужных компонентов
- `WSL` / `Hyper-V` / `VirtualMachinePlatform`
- тема, отображение, мышь, Bluetooth
- быстрый вход: отключение `Lock Screen`, требования пароля после сна и `UAC`
- `NVIDIA App`
- backup/restore пользовательских данных
- анализ, проверка состояния и оптимизация дисков
- hardware-aware логика: скан железа и адаптация сценария под конкретный ПК

## Что умеет

### Приложения
- выборочная установка приложений из required-профиля
- выборочная установка приложений из optional-профиля
- ручной выбор пакетов из каталога
- обновление всех установленных `winget`-пакетов

### Система
- базовая оптимизация Windows
- отдельный preset оптимизации под игры
- удаление части встроенного bloatware
- отключение безопасного набора ненужных optional-features
- настройка мыши
- настройка Bluetooth
- тема и визуальные параметры Windows
- переключение поиска Edge с `Bing` на `Google`

### Разработка и виртуализация
- включение `WSL`
- включение `VirtualMachinePlatform`
- включение `Hyper-V`

### Диагностика и обслуживание
- запуск `DISM`
- запуск `SFC`
- reset Windows Update
- reset network stack
- анализ дисков и томов
- проверка `TRIM`
- `ReTrim` для `SSD/NVMe`
- `Defrag` для `HDD`

### Железо
- скан оборудования
- автоопределение профиля ПК
- условная установка `NVIDIA App`
- автоматическое добавление `Samsung Magician`, если найден Samsung SSD
- рекомендации по BIOS и памяти
- диагностика `DeepCool AK400 Digital`

### Backup
- backup файлов перед переустановкой Windows
- restore после установки новой системы
- backup по JSON-конфигу
- manifest-файл после завершения резервного копирования

## Структура проекта

- [FirstSetup.ps1](c:\Users\danil\Desktop\FirstSetup-Windows\FirstSetup.ps1) - точка входа, меню, режимы `run/backup/restore`
- [Common.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Common.psm1) - логирование и общие утилиты
- [Installers.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Installers.psm1) - установка и обновление приложений
- [SystemSetup.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\SystemSetup.psm1) - Windows tweaks, debloat, features
- [Automation.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Automation.psm1) - config-driven запуск и auto-detect логика
- [HardwareProfile.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\HardwareProfile.psm1) - скан железа и рекомендации
- [Cooling.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Cooling.psm1) - DeepCool DIGITAL diagnostics
- [Fixes.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Fixes.psm1) - repair/reset сценарии
- [Backup.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Backup.psm1) - backup/restore через `robocopy`
- [Storage.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Storage.psm1) - анализ и оптимизация дисков
- [Nvidia.psm1](c:\Users\danil\Desktop\FirstSetup-Windows\Modules\Nvidia.psm1) - `NVIDIA App`

## Конфиги

- [AppCatalog.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\AppCatalog.json) - каталог required/optional приложений
- [DefaultSetup.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\DefaultSetup.json) - дефолтный универсальный профиль
- [Ryzen5700X-RTX4060-B550.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\Profiles\Ryzen5700X-RTX4060-B550.json) - профиль под Ryzen 5700X + RTX 4060 + B550
- [BackupTemplate.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\BackupTemplate.json) - шаблон backup-конфига

## Быстрый старт

Открой PowerShell от имени администратора:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\FirstSetup.ps1
```

## Основные режимы

### 1. Полная автоматическая настройка

```powershell
.\FirstSetup.ps1 -Run
```

Что делает этот режим:
- сканирует железо
- выбирает подходящий профиль
- адаптирует действия под текущий ПК
- запускает полный сценарий установки и настройки

### 2. Запуск с конкретным профилем

```powershell
.\FirstSetup.ps1 -ConfigPath .\Config\DefaultSetup.json -Run
```

Для твоего текущего ПК:

```powershell
.\FirstSetup.ps1 -ConfigPath .\Config\Profiles\Ryzen5700X-RTX4060-B550.json -Run
```

### 3. Backup перед переустановкой Windows

```powershell
.\FirstSetup.ps1 -Backup
```

### 4. Restore после переустановки Windows

```powershell
.\FirstSetup.ps1 -Restore
```

### 5. Backup/Restore с кастомным конфигом

```powershell
.\FirstSetup.ps1 -BackupConfigPath .\Config\BackupTemplate.json -Backup
.\FirstSetup.ps1 -BackupConfigPath .\Config\BackupTemplate.json -Restore
```

## Автоопределение железа

Сейчас auto-detect уже учитывает:
- `NVIDIA GPU`
- `Samsung SSD`
- наличие `Bluetooth`
- признак ноутбука
- известный профиль `Ryzen 7 5700X + RTX 4060 + B550 GAMING X V2`

Примеры поведения:
- если нет `NVIDIA`, установка `NVIDIA App` автоматически отключается
- если нет `Bluetooth`, Bluetooth-настройки пропускаются
- если найден `Samsung SSD`, в optional добавляется `Samsung Magician`
- если это ноутбук, агрессивный gaming preset отключается

## Каталог приложений

### Required
- Steam
- Discord
- Visual Studio Code
- Prism Launcher
- Epic Games Launcher
- Spotify

### Optional
- CCleaner
- Malwarebytes
- WinRAR
- Git
- Node.js LTS
- Koala Clash
- Samsung Magician
- DBeaver
- IntelliJ IDEA Community
- GitHub Desktop
- Blockbench
- r2modman
- Telegram Desktop
- Bitvise SSH Client
- Termius
- Lightshot

## Backup по умолчанию

Шаблон backup сохраняет:
- `Desktop`
- `Documents`
- `Pictures`
- `.ssh`
- `.gitconfig`
- настройки `VS Code`
- `Prism Launcher`

Опционально можно включить:
- `Downloads`
- `Videos`
- `Telegram Desktop`

Путь по умолчанию:

```text
D:\WindowsBackup
```

Перед запуском проверь и при необходимости измени его в [BackupTemplate.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\BackupTemplate.json).

## Важные замечания

- скрипт нужно запускать от администратора
- требуется установленный `winget`
- часть изменений требует перезагрузки
- `WSL`, `Hyper-V`, network reset и update reset почти всегда требуют reboot
- часть твиков перезапускает `Explorer`
- `NVIDIA App` запускает официальный инсталлятор NVIDIA
- смена поиска касается `Microsoft Edge`, а не системного поиска Windows
- не все vendor-specific драйверы и утилиты можно безопасно автоматизировать без учёта конкретного железа
- hardware-aware логика сделана консервативно: лучше пропустить действие, чем применить его не к тому ПК

## Известные аппаратные нюансы для твоего ПК

По текущему скану:
- обнаружен профиль `Ryzen 7 5700X + RTX 4060 + B550 GAMING X V2`
- есть `Samsung SSD`
- есть `Bluetooth`
- `DeepCool AK400 Digital` определяется системой
- память работает на `2400 MHz`

Последний пункт означает, что для твоей памяти очень вероятно выключен `XMP/DOCP`. Это нужно включать вручную в BIOS.

## Как расширять проект

1. Добавляй новые приложения в [AppCatalog.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\AppCatalog.json)
2. Меняй сценарий установки в [DefaultSetup.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\DefaultSetup.json)
3. Создавай новые hardware-specific профили в [Config\Profiles](c:\Users\danil\Desktop\FirstSetup-Windows\Config\Profiles)
4. Расширяй backup-список в [BackupTemplate.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\BackupTemplate.json)
5. Добавляй новые модули в `Modules`

## Рекомендуемый сценарий использования

1. Настроить [BackupTemplate.json](c:\Users\danil\Desktop\FirstSetup-Windows\Config\BackupTemplate.json)
2. Запустить `.\FirstSetup.ps1 -Backup` на старой Windows
3. Переустановить Windows
4. Запустить `.\FirstSetup.ps1 -Run`
5. Запустить `.\FirstSetup.ps1 -Restore`
6. Проверить BIOS-пункты вроде `XMP/DOCP`, `Above 4G Decoding`, `Re-Size BAR`

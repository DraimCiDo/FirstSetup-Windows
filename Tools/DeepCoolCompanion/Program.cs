using System.Drawing;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using HidSharp;
using LibreHardwareMonitor.Hardware;
using Microsoft.Win32;

namespace DeepCoolCompanion;

internal enum DisplayMode
{
    Temperature,
    Utilization,
    Automatic
}

internal enum TemperatureUnit
{
    Celsius,
    Fahrenheit
}

internal sealed class AppSettings
{
    public DisplayMode DisplayMode { get; set; } = DisplayMode.Automatic;
    public TemperatureUnit Unit { get; set; } = TemperatureUnit.Celsius;
    public bool StartWithWindows { get; set; } = true;
    public bool StopOfficialAppOnLaunch { get; set; } = true;
    public bool WarningEnabled { get; set; } = true;
}

internal sealed record CpuMetrics(float? TemperatureC, float? LoadPercent);

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        try
        {
            using var mutex = new Mutex(true, @"Local\FirstSetup-DeepCoolCompanion", out var isPrimaryInstance);
            if (!isPrimaryInstance) { return; }

            ApplicationConfiguration.Initialize();
            Application.Run(new DeepCoolApplicationContext());
        }
        catch (Exception ex)
        {
            var configDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "FirstSetup", "DeepCoolCompanion");
            Directory.CreateDirectory(configDirectory);
            var logPath = Path.Combine(configDirectory, "fatal.log");
            File.AppendAllText(logPath, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {ex}{Environment.NewLine}");
        }
    }
}

internal sealed class DeepCoolApplicationContext : ApplicationContext
{
    private const int VendorId = 13875;
    private const int ProductId = 1;
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "DeepCoolCompanion";

    private readonly Computer _computer;
    private readonly NotifyIcon _notifyIcon;
    private readonly SynchronizationContext _uiContext;
    private readonly CancellationTokenSource _cancellationTokenSource;
    private readonly string _configDirectory;
    private readonly string _configPath;
    private readonly string _logPath;
    private readonly ToolStripMenuItem _temperatureModeMenuItem;
    private readonly ToolStripMenuItem _utilizationModeMenuItem;
    private readonly ToolStripMenuItem _automaticModeMenuItem;
    private readonly ToolStripMenuItem _celsiusMenuItem;
    private readonly ToolStripMenuItem _fahrenheitMenuItem;
    private readonly ToolStripMenuItem _startupMenuItem;
    private AppSettings _settings;
    private int _automaticTick;
    private int _consecutiveFailures;
    private bool _reportLengthsLogged;
    private string _lastStatusText = "DeepCool Companion";

    public DeepCoolApplicationContext()
    {
        _uiContext = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
        _cancellationTokenSource = new CancellationTokenSource();
        _configDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "FirstSetup", "DeepCoolCompanion");
        _configPath = Path.Combine(_configDirectory, "settings.json");
        _logPath = Path.Combine(_configDirectory, "companion.log");
        Directory.CreateDirectory(_configDirectory);

        _settings = LoadSettings();

        _computer = new Computer
        {
            IsCpuEnabled = true
        };
        _computer.Open();

        _temperatureModeMenuItem = new ToolStripMenuItem("Показывать температуру", null, (_, _) =>
        {
            _settings.DisplayMode = DisplayMode.Temperature;
            SaveSettings();
            RefreshMenuChecks();
        });

        _utilizationModeMenuItem = new ToolStripMenuItem("Показывать загрузку CPU", null, (_, _) =>
        {
            _settings.DisplayMode = DisplayMode.Utilization;
            SaveSettings();
            RefreshMenuChecks();
        });

        _automaticModeMenuItem = new ToolStripMenuItem("Автоматическое переключение", null, (_, _) =>
        {
            _settings.DisplayMode = DisplayMode.Automatic;
            _automaticTick = 0;
            SaveSettings();
            RefreshMenuChecks();
        });

        _celsiusMenuItem = new ToolStripMenuItem("Цельсий", null, (_, _) =>
        {
            _settings.Unit = TemperatureUnit.Celsius;
            SaveSettings();
            RefreshMenuChecks();
        });

        _fahrenheitMenuItem = new ToolStripMenuItem("Фаренгейт", null, (_, _) =>
        {
            _settings.Unit = TemperatureUnit.Fahrenheit;
            SaveSettings();
            RefreshMenuChecks();
        });

        _startupMenuItem = new ToolStripMenuItem("Запускать вместе с Windows", null, (_, _) =>
        {
            _settings.StartWithWindows = !_settings.StartWithWindows;
            SaveSettings();
            ApplyStartupRegistration();
            RefreshMenuChecks();
        });

        var contextMenu = new ContextMenuStrip();
        contextMenu.Items.Add(_temperatureModeMenuItem);
        contextMenu.Items.Add(_utilizationModeMenuItem);
        contextMenu.Items.Add(_automaticModeMenuItem);
        contextMenu.Items.Add(new ToolStripSeparator());
        contextMenu.Items.Add(_celsiusMenuItem);
        contextMenu.Items.Add(_fahrenheitMenuItem);
        contextMenu.Items.Add(new ToolStripSeparator());
        contextMenu.Items.Add(_startupMenuItem);
        contextMenu.Items.Add(new ToolStripMenuItem("Открыть папку логов", null, (_, _) => OpenLogsDirectory()));
        contextMenu.Items.Add(new ToolStripMenuItem("Остановить официальный DeepCool", null, (_, _) => StopOfficialDeepCoolProcesses()));
        contextMenu.Items.Add(new ToolStripMenuItem("Выход", null, (_, _) => ExitThread()));

        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            ContextMenuStrip = contextMenu,
            Text = "DeepCool Companion",
            Visible = true
        };

        RefreshMenuChecks();
        ApplyStartupRegistration();

        if (_settings.StopOfficialAppOnLaunch)
        {
            StopOfficialDeepCoolProcesses();
        }

        Log("DeepCool Companion started.");
        _ = RunUpdateLoopAsync(_cancellationTokenSource.Token);
    }

    protected override void ExitThreadCore()
    {
        _cancellationTokenSource.Cancel();
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _computer.Close();
        base.ExitThreadCore();
    }

    private async Task RunUpdateLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            UpdateDevice();

            try
            {
                await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }
    }

    private void UpdateDevice()
    {
        try
        {
            var device = FindDevice();
            if (device is null)
            {
                _consecutiveFailures++;
                SetStatus("AK400 не найден");
                return;
            }

            var metrics = ReadCpuMetrics();
            if (metrics.TemperatureC is null && metrics.LoadPercent is null)
            {
                _consecutiveFailures++;
                SetStatus("Нет данных датчиков CPU");
                return;
            }

            var effectiveMode = GetEffectiveMode();
            LogReportLengths(device);
            var packet = BuildRp003Packet(metrics, effectiveMode);

            if (!device.TryOpen(out HidStream? stream) || stream is null)
            {
                throw new InvalidOperationException("Не удалось открыть HID-устройство.");
            }

            using (stream)
            {
                stream.WriteTimeout = 250;
                TrySendPacket(stream, device, packet);
            }

            _consecutiveFailures = 0;
            var temperatureText = metrics.TemperatureC is null ? "--" : $"{Math.Round(metrics.TemperatureC.Value)}C";
            var loadText = metrics.LoadPercent is null ? "--" : $"{Math.Round(metrics.LoadPercent.Value)}%";
            SetStatus($"AK400 OK | {temperatureText} | {loadText}");
        }
        catch (Exception ex)
        {
            _consecutiveFailures++;
            if (_consecutiveFailures <= 3 || (_consecutiveFailures % 10) == 0)
            {
                Log($"Update failed: {ex.Message}");
            }
            SetStatus("Ошибка отправки в AK400");
        }
    }

    private HidDevice? FindDevice()
    {
        return DeviceList.Local.GetHidDevices(VendorId, ProductId).FirstOrDefault();
    }

    private DisplayMode GetEffectiveMode()
    {
        if (_settings.DisplayMode != DisplayMode.Automatic)
        {
            return _settings.DisplayMode;
        }

        _automaticTick++;
        if (_automaticTick > 10)
        {
            _automaticTick = 1;
        }

        return _automaticTick <= 5 ? DisplayMode.Temperature : DisplayMode.Utilization;
    }

    private byte[] BuildRp003Packet(CpuMetrics metrics, DisplayMode effectiveMode)
    {
        var cpuLoad = ClampToByte(metrics.LoadPercent ?? 0);
        var gaugeValue = Math.Clamp((int)Math.Round(cpuLoad / 10.0), 1, 10);
        var warningValue = (_settings.WarningEnabled && (metrics.TemperatureC ?? 0) >= 90f) ? (byte)1 : (byte)0;

        return effectiveMode switch
        {
            DisplayMode.Utilization => [0x10, 0x4C, (byte)gaugeValue, .. ToDigits(cpuLoad), warningValue],
            _ => [0x10, GetUnitCode(), (byte)gaugeValue, .. ToDigits(GetDisplayTemperature(metrics.TemperatureC)), warningValue]
        };
    }

    private static byte[] NormalizePacketForDevice(HidDevice device, byte[] packet)
    {
        var outputLength = device.GetMaxOutputReportLength();
        if (outputLength <= 0 || outputLength == packet.Length)
        {
            return packet;
        }

        var buffer = new byte[outputLength];
        Array.Copy(packet, buffer, Math.Min(packet.Length, buffer.Length));
        return buffer;
    }

    private static byte[] NormalizePacketForFeature(HidDevice device, byte[] packet)
    {
        var featureLength = device.GetMaxFeatureReportLength();
        if (featureLength <= 0 || featureLength == packet.Length)
        {
            return packet;
        }

        var buffer = new byte[featureLength];
        Array.Copy(packet, buffer, Math.Min(packet.Length, buffer.Length));
        return buffer;
    }

    private static void TrySendPacket(HidStream stream, HidDevice device, byte[] packet)
    {
        try
        {
            stream.Write(NormalizePacketForDevice(device, packet));
        }
        catch (TimeoutException)
        {
            stream.SetFeature(NormalizePacketForFeature(device, packet));
        }
        catch (IOException)
        {
            stream.SetFeature(NormalizePacketForFeature(device, packet));
        }
    }

    private byte GetUnitCode()
    {
        return _settings.Unit == TemperatureUnit.Fahrenheit ? (byte)35 : (byte)19;
    }

    private int GetDisplayTemperature(float? temperatureC)
    {
        var value = temperatureC ?? 0;
        if (_settings.Unit == TemperatureUnit.Fahrenheit)
        {
            value = 32f + (value * 1.8f);
        }

        return ClampToByte(value);
    }

    private static int ClampToByte(float value)
    {
        return Math.Clamp((int)Math.Round(value), 0, 999);
    }

    private static byte[] ToDigits(int value)
    {
        var normalized = Math.Clamp(value, 0, 999);
        return
        [
            (byte)(normalized / 100),
            (byte)((normalized / 10) % 10),
            (byte)(normalized % 10)
        ];
    }

    private CpuMetrics ReadCpuMetrics()
    {
        float? packageTemperature = null;
        float? maxTemperature = null;
        float? totalLoad = null;

        foreach (var hardware in EnumerateHardware(_computer.Hardware))
        {
            hardware.Update();

            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.Value is null) { continue; }

                if (sensor.SensorType == SensorType.Temperature)
                {
                    if (sensor.Name.Contains("Package", StringComparison.OrdinalIgnoreCase))
                    {
                        packageTemperature = sensor.Value.Value;
                    }

                    if (maxTemperature is null || sensor.Value.Value > maxTemperature.Value)
                    {
                        maxTemperature = sensor.Value.Value;
                    }
                }

                if (sensor.SensorType == SensorType.Load &&
                    (sensor.Name.Contains("CPU Total", StringComparison.OrdinalIgnoreCase) ||
                     sensor.Name.Equals("Total", StringComparison.OrdinalIgnoreCase)))
                {
                    totalLoad = sensor.Value.Value;
                }
            }
        }

        return new CpuMetrics(packageTemperature ?? maxTemperature, totalLoad);
    }

    private static IEnumerable<IHardware> EnumerateHardware(IEnumerable<IHardware> hardwareItems)
    {
        foreach (var hardware in hardwareItems)
        {
            yield return hardware;

            foreach (var subHardware in EnumerateHardware(hardware.SubHardware))
            {
                yield return subHardware;
            }
        }
    }

    private void RefreshMenuChecks()
    {
        _temperatureModeMenuItem.Checked = _settings.DisplayMode == DisplayMode.Temperature;
        _utilizationModeMenuItem.Checked = _settings.DisplayMode == DisplayMode.Utilization;
        _automaticModeMenuItem.Checked = _settings.DisplayMode == DisplayMode.Automatic;
        _celsiusMenuItem.Checked = _settings.Unit == TemperatureUnit.Celsius;
        _fahrenheitMenuItem.Checked = _settings.Unit == TemperatureUnit.Fahrenheit;
        _startupMenuItem.Checked = _settings.StartWithWindows;
    }

    private void ApplyStartupRegistration()
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath);
        if (key is null) { return; }

        if (_settings.StartWithWindows)
        {
            key.SetValue(RunValueName, $"\"{Application.ExecutablePath}\"");
        }
        else
        {
            key.DeleteValue(RunValueName, false);
        }
    }

    private void OpenLogsDirectory()
    {
        Directory.CreateDirectory(_configDirectory);
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = _configDirectory,
            UseShellExecute = true
        });
    }

    private void StopOfficialDeepCoolProcesses()
    {
        foreach (var process in System.Diagnostics.Process.GetProcessesByName("deepcool-digital"))
        {
            try
            {
                process.Kill(true);
            }
            catch
            {
            }
        }
    }

    private AppSettings LoadSettings()
    {
        try
        {
            if (File.Exists(_configPath))
            {
                var content = File.ReadAllText(_configPath);
                var settings = JsonSerializer.Deserialize<AppSettings>(content);
                if (settings is not null)
                {
                    return settings;
                }
            }
        }
        catch (Exception ex)
        {
            Log($"Failed to load settings: {ex.Message}");
        }

        return new AppSettings();
    }

    private void SaveSettings()
    {
        try
        {
            var json = JsonSerializer.Serialize(_settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(_configPath, json);
        }
        catch (Exception ex)
        {
            Log($"Failed to save settings: {ex.Message}");
        }
    }

    private void SetStatus(string status)
    {
        if (status == _lastStatusText) { return; }

        _lastStatusText = status;
        _uiContext.Post(_ =>
        {
            _notifyIcon.Text = status.Length > 63 ? status[..63] : status;
        }, null);
    }

    private void LogReportLengths(HidDevice device)
    {
        if (_reportLengthsLogged) { return; }

        _reportLengthsLogged = true;
        Log($"Report lengths: output={device.GetMaxOutputReportLength()}, feature={device.GetMaxFeatureReportLength()}, input={device.GetMaxInputReportLength()}");
    }

    private void Log(string message)
    {
        try
        {
            File.AppendAllText(_logPath, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}{Environment.NewLine}");
        }
        catch
        {
        }
    }
}

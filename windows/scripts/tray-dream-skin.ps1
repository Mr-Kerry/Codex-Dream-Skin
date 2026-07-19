[CmdletBinding()]
param([int]$Port = 9335)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
if (-not ('CodexDreamSkin.OpacitySlider' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace CodexDreamSkin {
  public sealed class OpacitySlider : Control {
    private int currentValue = 30;
    private bool dragging;
    public event EventHandler ValueChanged;

    public int Value {
      get { return currentValue; }
      set {
        int next = Math.Max(0, Math.Min(100, value));
        if (next == currentValue) return;
        currentValue = next;
        Invalidate();
        EventHandler handler = ValueChanged;
        if (handler != null) handler(this, EventArgs.Empty);
      }
    }

    public OpacitySlider() {
      DoubleBuffered = true;
      TabStop = true;
      Size = new Size(252, 64);
      BackColor = Color.FromArgb(250, 247, 250);
      Cursor = Cursors.Hand;
      SetStyle(ControlStyles.ResizeRedraw, true);
    }

    private void SetFromX(int x) {
      const int inset = 18;
      int width = Math.Max(1, ClientSize.Width - inset * 2);
      Value = (int)Math.Round(Math.Max(0, Math.Min(width, x - inset)) * 100.0 / width);
    }

    private static GraphicsPath RoundedRectangle(Rectangle bounds, int radius) {
      GraphicsPath path = new GraphicsPath();
      int diameter = radius * 2;
      path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
      path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
      path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
      path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
      path.CloseFigure();
      return path;
    }

    protected override void OnMouseDown(MouseEventArgs e) {
      base.OnMouseDown(e);
      if (e.Button != MouseButtons.Left) return;
      dragging = true;
      Capture = true;
      Focus();
      SetFromX(e.X);
    }

    protected override void OnMouseMove(MouseEventArgs e) {
      base.OnMouseMove(e);
      if (dragging) SetFromX(e.X);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
      base.OnMouseUp(e);
      dragging = false;
      Capture = false;
    }

    protected override void OnKeyDown(KeyEventArgs e) {
      base.OnKeyDown(e);
      if (e.KeyCode == Keys.Left || e.KeyCode == Keys.Down) { Value -= 1; e.Handled = true; }
      if (e.KeyCode == Keys.Right || e.KeyCode == Keys.Up) { Value += 1; e.Handled = true; }
      if (e.KeyCode == Keys.PageDown) { Value -= 10; e.Handled = true; }
      if (e.KeyCode == Keys.PageUp) { Value += 10; e.Handled = true; }
      if (e.KeyCode == Keys.Home) { Value = 0; e.Handled = true; }
      if (e.KeyCode == Keys.End) { Value = 100; e.Handled = true; }
    }

    protected override void OnPaint(PaintEventArgs e) {
      base.OnPaint(e);
      Graphics graphics = e.Graphics;
      graphics.SmoothingMode = SmoothingMode.AntiAlias;
      graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
      Rectangle panelBounds = new Rectangle(0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
      using (GraphicsPath panel = RoundedRectangle(panelBounds, 9))
      using (SolidBrush surface = new SolidBrush(Color.FromArgb(250, 247, 250)))
      using (Pen outline = new Pen(Color.FromArgb(232, 224, 232), 1)) {
        graphics.FillPath(surface, panel);
        graphics.DrawPath(outline, panel);
      }
      using (Font labelFont = new Font("Segoe UI", 9.0f, FontStyle.Regular))
      using (Font valueFont = new Font("Segoe UI Semibold", 9.0f, FontStyle.Bold))
      using (SolidBrush label = new SolidBrush(Color.FromArgb(82, 73, 84)))
      using (SolidBrush value = new SolidBrush(Color.FromArgb(143, 89, 137))) {
        graphics.DrawString("\u80cc\u666f\u900f\u660e\u5ea6", labelFont, label, 14, 8);
        SizeF valueSize = graphics.MeasureString(currentValue + "%", valueFont);
        graphics.DrawString(currentValue + "%", valueFont, value, ClientSize.Width - valueSize.Width - 13, 8);
      }
      const int inset = 18;
      int y = 44;
      int width = Math.Max(1, ClientSize.Width - inset * 2);
      int thumbX = inset + (int)Math.Round(width * currentValue / 100.0);
      using (Pen empty = new Pen(Color.FromArgb(222, 214, 223), 4)) {
        empty.StartCap = empty.EndCap = LineCap.Round;
        graphics.DrawLine(empty, inset, y, inset + width, y);
      }
      using (Pen fill = new Pen(Color.FromArgb(174, 116, 165), 4)) {
        fill.StartCap = fill.EndCap = LineCap.Round;
        graphics.DrawLine(fill, inset, y, thumbX, y);
      }
      if (Focused) {
        using (SolidBrush glow = new SolidBrush(Color.FromArgb(38, 174, 116, 165))) {
          graphics.FillEllipse(glow, thumbX - 12, y - 12, 24, 24);
        }
      }
      using (SolidBrush thumb = new SolidBrush(Color.White)) {
        graphics.FillEllipse(thumb, thumbX - 9, y - 9, 18, 18);
      }
      using (Pen border = new Pen(Color.FromArgb(174, 123, 167), 2)) {
        graphics.DrawEllipse(border, thumbX - 9, y - 9, 18, 18);
      }
    }
  }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing
}
. (Join-Path $PSScriptRoot 'common-windows.ps1')
. (Join-Path $PSScriptRoot 'theme-windows.ps1')

Assert-DreamSkinPort -Port $Port
$SkillRoot = Split-Path -Parent $PSScriptRoot
$StateRoot = Join-Path $env:LOCALAPPDATA 'CodexDreamSkin'
$paths = Get-DreamSkinThemePaths -StateRoot $StateRoot
if (-not (Test-Path -LiteralPath (Join-Path $paths.Active 'theme.json') -PathType Leaf)) {
  $paths = Initialize-DreamSkinThemeStore -SkillRoot $SkillRoot -StateRoot $StateRoot
}
$powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
$startScript = Join-Path $PSScriptRoot 'start-dream-skin.ps1'
$restoreScript = Join-Path $PSScriptRoot 'restore-dream-skin.ps1'

$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$mutex = [System.Threading.Mutex]::new($false, "Local\CodexDreamSkin.$sid.Tray")
$acquired = $false
try {
  try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
  if (-not $acquired) { exit 0 }

  $notify = [System.Windows.Forms.NotifyIcon]::new()
  $notify.Icon = [System.Drawing.SystemIcons]::Application
  $notify.Text = 'Codex Dream Skin'
  $notify.Visible = $true
  $menu = [System.Windows.Forms.ContextMenuStrip]::new()
  $notify.ContextMenuStrip = $menu
  $opacityRefreshTimer = [System.Windows.Forms.Timer]::new()
  $opacityRefreshTimer.Interval = 140
  $opacityStatusTimer = [System.Windows.Forms.Timer]::new()
  $opacityStatusTimer.Interval = 100
  $opacityRefreshState = @{
    Process = $null
    Pending = $false
    Menu = $null
    Percent = 30
  }

  function Show-DreamSkinTrayError {
    param([string]$Message)
    [void][System.Windows.Forms.MessageBox]::Show(
      $Message,
      'Codex Dream Skin',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error
    )
  }

  function Start-DreamSkinPowerShell {
    param([Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())
    $scriptToken = ConvertTo-DreamSkinProcessArgument -Value $Script
    $argumentLine = '-NoProfile -ExecutionPolicy RemoteSigned -File ' + $scriptToken
    if ($Arguments.Count -gt 0) { $argumentLine += ' ' + ($Arguments -join ' ') }
    Start-Process -FilePath $powershell -ArgumentList $argumentLine | Out-Null
  }

  function Invoke-DreamSkinLiveThemeRefresh {
    $state = Read-DreamSkinState -Path $paths.State
    if ($null -eq $state -or -not $state.nodePath -or -not $state.injectorPath -or
      -not $state.browserId -or -not $state.port) {
      throw 'Dream Skin runtime state is unavailable. Apply the skin once before using live opacity.'
    }
    $arguments = @(
      (ConvertTo-DreamSkinProcessArgument -Value "$($state.injectorPath)"),
      '--once',
      '--port', "$($state.port)",
      '--browser-id', (ConvertTo-DreamSkinProcessArgument -Value "$($state.browserId)"),
      '--theme-dir', (ConvertTo-DreamSkinProcessArgument -Value $paths.Active)
    ) -join ' '
    return Start-Process -FilePath "$($state.nodePath)" -ArgumentList $arguments -WindowStyle Hidden -PassThru
  }

  function Write-DreamSkinOpacity {
    $current = Read-DreamSkinTheme -ThemeDirectory $paths.Active -SkipImageMetadata
    if ($null -eq $current.Theme.art) {
      $current.Theme | Add-Member -NotePropertyName art -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    $value = [Math]::Round($opacityRefreshState.Percent / 100, 2)
    $current.Theme.art | Add-Member -NotePropertyName opacity -NotePropertyValue $value -Force
    Write-DreamSkinTheme -ThemeDirectory $paths.Active -Theme $current.Theme
  }

  function Get-DreamSkinOpacityPercent {
    param([AllowNull()][object]$Theme)
    $property = $Theme.art.PSObject.Properties['opacity']
    if ($null -eq $property -or $null -eq $property.Value) { return 30 }
    try {
      $value = [System.Convert]::ToDouble(
        $property.Value,
        [System.Globalization.CultureInfo]::InvariantCulture
      )
      if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { return 30 }
      return [int][Math]::Round([Math]::Min(1.0, [Math]::Max(0.0, $value)) * 100.0)
    } catch {
      return 30
    }
  }

  $opacityRefreshTimer.add_Tick({
    $opacityRefreshTimer.Stop()
    if ($null -ne $opacityRefreshState.Process -and -not $opacityRefreshState.Process.HasExited) {
      $opacityRefreshState.Pending = $true
      return
    }
    try {
      Write-DreamSkinOpacity
      if ($null -ne $opacityRefreshState.Menu -and -not $opacityRefreshState.Menu.IsDisposed) {
        $opacityRefreshState.Menu.Text = "背景透明度  $($opacityRefreshState.Percent)% · 应用中"
      }
      $opacityRefreshState.Process = Invoke-DreamSkinLiveThemeRefresh
      $opacityStatusTimer.Start()
    } catch {
      Show-DreamSkinTrayError -Message $_.Exception.Message
    }
  })

  $opacityStatusTimer.add_Tick({
    if ($null -eq $opacityRefreshState.Process -or -not $opacityRefreshState.Process.HasExited) { return }
    $opacityStatusTimer.Stop()
    $exitCode = $opacityRefreshState.Process.ExitCode
    $opacityRefreshState.Process.Dispose()
    $opacityRefreshState.Process = $null
    if ($exitCode -ne 0) {
      if ($opacityRefreshState.Pending) {
        $opacityRefreshState.Pending = $false
        $opacityRefreshTimer.Start()
        return
      }
      if ($null -ne $opacityRefreshState.Menu -and -not $opacityRefreshState.Menu.IsDisposed) {
        $opacityRefreshState.Menu.Text = "背景透明度  $($opacityRefreshState.Percent)% · 同步失败"
      }
      Show-DreamSkinTrayError -Message '背景透明度未能同步到当前 Codex 窗口。'
      return
    }
    if ($opacityRefreshState.Pending) {
      $opacityRefreshState.Pending = $false
      $opacityRefreshTimer.Start()
      return
    }
    if ($null -ne $opacityRefreshState.Menu -and -not $opacityRefreshState.Menu.IsDisposed) {
      $opacityRefreshState.Menu.Text = "背景透明度  $($opacityRefreshState.Percent)% · 已同步"
    }
  })

  function Add-DreamSkinTrayItem {
    param(
      [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Windows.Forms.ToolStripItemCollection]$Items,
      [Parameter(Mandatory = $true)][string]$Text,
      [AllowNull()][scriptblock]$Action,
      [bool]$Enabled = $true
    )
    $item = [System.Windows.Forms.ToolStripMenuItem]::new($Text)
    $item.Enabled = $Enabled
    if ($null -ne $Action) {
      $item.add_Click({
        try { & $Action } catch { Show-DreamSkinTrayError -Message $_.Exception.Message }
      }.GetNewClosure())
    }
    [void]$Items.Add($item)
    return $item
  }

  function Rebuild-DreamSkinTrayMenu {
    $menu.Items.Clear()
    $paused = Test-DreamSkinPaused -StateRoot $StateRoot
    $state = $null
    try { $state = Read-DreamSkinState -Path $paths.State } catch {}
    $active = $null
    try { $active = Read-DreamSkinTheme -ThemeDirectory $paths.Active -SkipImageMetadata } catch {}
    $status = if ($paused) { '状态：已暂停' } elseif ($state) { '状态：运行中' } else { '状态：未运行' }
    if ($null -ne $active -and $null -ne $active.Theme -and $active.Theme.name) {
      $status += " · $($active.Theme.name)"
    }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $status -Action $null -Enabled $false
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())

    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '应用或重新应用' -Action {
      Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
      Start-DreamSkinPowerShell -Script $startScript -Arguments @('-Port', "$Port", '-PromptRestart')
    }
    $pauseText = if ($paused) { '继续显示皮肤' } else { '暂停皮肤' }
    $nextPaused = -not $paused
    $pauseAction = {
      Set-DreamSkinPaused -Paused $nextPaused -StateRoot $StateRoot | Out-Null
    }.GetNewClosure()
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text $pauseText -Action $pauseAction
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '更换背景图' -Action {
      $dialog = [System.Windows.Forms.OpenFileDialog]::new()
      $dialog.Title = '选择 Codex Dream Skin 背景图'
      $dialog.Filter = 'Image files|*.png;*.jpg;*.jpeg;*.webp|All files|*.*'
      $dialog.Multiselect = $false
      try {
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
          $null = Set-DreamSkinActiveTheme -ImagePath $dialog.FileName -Theme $null -StateRoot $StateRoot
          Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
          $notify.ShowBalloonTip(1800, 'Codex Dream Skin', '背景图已更新。', [System.Windows.Forms.ToolTipIcon]::Info)
        }
      } finally {
        $dialog.Dispose()
      }
    }

    $opacityPercent = Get-DreamSkinOpacityPercent -Theme $active.Theme
    $opacityRefreshState.Percent = $opacityPercent
    $opacityStatus = if ($null -ne $opacityRefreshState.Process -and -not $opacityRefreshState.Process.HasExited) {
      '应用中'
    } else {
      '已同步'
    }
    $opacityMenu = [System.Windows.Forms.ToolStripMenuItem]::new("背景透明度  $opacityPercent% · $opacityStatus")
    $opacityRefreshState.Menu = $opacityMenu
    $opacitySlider = [CodexDreamSkin.OpacitySlider]::new()
    $opacitySlider.Value = $opacityPercent
    $opacityHost = [System.Windows.Forms.ToolStripControlHost]::new($opacitySlider)
    $opacityHost.AutoSize = $false
    $opacityHost.Size = [System.Drawing.Size]::new(264, 72)
    $opacityHost.Padding = [System.Windows.Forms.Padding]::new(6, 4, 6, 4)
    $opacityHost.BackColor = [System.Drawing.Color]::FromArgb(250, 247, 250)
    $opacitySlider.add_ValueChanged({
      try {
        $percent = $opacitySlider.Value
        $opacityRefreshState.Percent = $percent
        if ($null -ne $opacityRefreshState.Process -and -not $opacityRefreshState.Process.HasExited) {
          $opacityRefreshState.Pending = $true
        }
        $opacityMenu.Text = "背景透明度  $percent% · 应用中"
        $opacityRefreshTimer.Stop()
        $opacityRefreshTimer.Start()
      } catch {
        Show-DreamSkinTrayError -Message $_.Exception.Message
      }
    }.GetNewClosure())
    [void]$opacityMenu.DropDownItems.Add($opacityHost)
    [void]$menu.Items.Add($opacityMenu)

    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '保存当前主题' -Action {
      $name = [Microsoft.VisualBasic.Interaction]::InputBox('输入主题名称：', '保存 Codex Dream Skin 主题', '')
      if ($name.Trim()) {
        $saved = Save-DreamSkinCurrentTheme -Name $name -StateRoot $StateRoot
        $notify.ShowBalloonTip(1800, 'Codex Dream Skin', "已保存：$($saved.Theme.name)", [System.Windows.Forms.ToolTipIcon]::Info)
      }
    }

    $savedMenu = [System.Windows.Forms.ToolStripMenuItem]::new('已保存主题')
    $savedThemes = @(Get-DreamSkinSavedThemes -StateRoot $StateRoot -SkipImageMetadata)
    if ($savedThemes.Count -eq 0) {
      $empty = [System.Windows.Forms.ToolStripMenuItem]::new('暂无已保存主题')
      $empty.Enabled = $false
      [void]$savedMenu.DropDownItems.Add($empty)
    } else {
      foreach ($saved in $savedThemes) {
        $savedPath = $saved.Path
        $savedName = $saved.Name
        $savedAction = {
          $null = Use-DreamSkinSavedTheme -ThemeDirectory $savedPath -StateRoot $StateRoot
          Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
          $notify.ShowBalloonTip(1800, 'Codex Dream Skin', "已应用：$savedName", [System.Windows.Forms.ToolTipIcon]::Info)
        }.GetNewClosure()
        $null = Add-DreamSkinTrayItem -Items $savedMenu.DropDownItems -Text $savedName -Action $savedAction
      }
    }
    [void]$menu.Items.Add($savedMenu)

    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '打开图片文件夹' -Action {
      Start-Process -FilePath explorer.exe -ArgumentList @($paths.Images) | Out-Null
    }
    [void]$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new())
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '完全恢复 Codex' -Action {
      Start-DreamSkinPowerShell -Script $restoreScript -Arguments @(
        '-Port', "$Port", '-RestoreBaseTheme', '-PromptRestart'
      )
      $notify.Visible = $false
      [System.Windows.Forms.Application]::Exit()
    }
    $null = Add-DreamSkinTrayItem -Items $menu.Items -Text '退出托盘' -Action {
      $notify.Visible = $false
      [System.Windows.Forms.Application]::Exit()
    }
  }

  $menu.add_Opening({ Rebuild-DreamSkinTrayMenu })
  $notify.add_DoubleClick({
    try {
      Set-DreamSkinPaused -Paused $false -StateRoot $StateRoot | Out-Null
      Start-DreamSkinPowerShell -Script $startScript -Arguments @('-Port', "$Port", '-PromptRestart')
    } catch {
      Show-DreamSkinTrayError -Message $_.Exception.Message
    }
  })
  [System.Windows.Forms.Application]::Run()
} finally {
  if ($null -ne $opacityRefreshTimer) { $opacityRefreshTimer.Dispose() }
  if ($null -ne $opacityStatusTimer) { $opacityStatusTimer.Dispose() }
  if ($null -ne $opacityRefreshState.Process) { $opacityRefreshState.Process.Dispose() }
  if ($null -ne $notify) { $notify.Dispose() }
  if ($acquired) { try { $mutex.ReleaseMutex() } catch {} }
  $mutex.Dispose()
}

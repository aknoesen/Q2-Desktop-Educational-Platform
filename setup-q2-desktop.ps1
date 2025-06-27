# Q2 Desktop App Setup Script
# Creates directory structure and files for the Electron application

param(
    [string]$ProjectRoot = "C:\Users\aknoesen\Documents\Knoesen\Project-Root-Q2QTI"
)

Write-Host "🚀 Q2 Desktop App Setup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Verify project root exists
if (-not (Test-Path $ProjectRoot)) {
    Write-Host "❌ Error: Project root directory not found: $ProjectRoot" -ForegroundColor Red
    Write-Host "Please specify the correct path with -ProjectRoot parameter" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Project Root: $ProjectRoot" -ForegroundColor Green

# Set the Q2 Desktop App directory
$AppDir = Join-Path $ProjectRoot "Q2-Desktop-App"

# Create main directory structure
Write-Host "`n📂 Creating directory structure..." -ForegroundColor Yellow

$Directories = @(
    $AppDir,
    (Join-Path $AppDir "src"),
    (Join-Path $AppDir "assets"),
    (Join-Path $AppDir "temp"),
    (Join-Path $AppDir "error-reports")
)

foreach ($Dir in $Directories) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        Write-Host "  ✅ Created: $($Dir.Replace($ProjectRoot, '.'))" -ForegroundColor Green
    } else {
        Write-Host "  ⏭️  Exists: $($Dir.Replace($ProjectRoot, '.'))" -ForegroundColor Yellow
    }
}

# Create package.json
Write-Host "`n📄 Creating package.json..." -ForegroundColor Yellow
$PackageJsonPath = Join-Path $AppDir "package.json"
$PackageJsonContent = @'
{
  "name": "q2-desktop-app",
  "version": "1.0.0",
  "description": "Desktop application for Q2 workflow - prompt generation, validation, and Q2LMS integration",
  "main": "main.js",
  "author": "Q2 Project",
  "license": "MIT",
  "scripts": {
    "start": "electron .",
    "dev": "electron . --dev",
    "build": "electron-builder",
    "build-win": "electron-builder --win",
    "pack": "electron-builder --dir",
    "dist": "electron-builder --publish=never"
  },
  "devDependencies": {
    "electron": "^28.0.0",
    "electron-builder": "^24.0.0"
  },
  "dependencies": {
    "path": "^0.12.7",
    "fs-extra": "^11.2.0"
  },
  "build": {
    "appId": "com.q2project.desktop",
    "productName": "Q2 Desktop",
    "directories": {
      "output": "dist"
    },
    "files": [
      "**/*",
      "!**/node_modules/*/{CHANGELOG.md,README.md,README,readme.md,readme}",
      "!**/node_modules/*/{test,__tests__,tests,powered-test,example,examples}",
      "!**/node_modules/*.d.ts",
      "!**/node_modules/.bin"
    ],
    "win": {
      "target": "nsis",
      "icon": "assets/icon.ico"
    },
    "mac": {
      "target": "dmg",
      "icon": "assets/icon.icns"
    },
    "linux": {
      "target": "AppImage",
      "icon": "assets/icon.png"
    }
  }
}
'@

Set-Content -Path $PackageJsonPath -Value $PackageJsonContent -Encoding UTF8
Write-Host "  ✅ Created: package.json" -ForegroundColor Green

# Create main.js (Electron main process)
Write-Host "`n📄 Creating main.js..." -ForegroundColor Yellow
$MainJsPath = Join-Path $AppDir "main.js"
$MainJsContent = @'
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs-extra');
const { spawn } = require('child_process');

class Q2DesktopApp {
    constructor() {
        this.mainWindow = null;
        this.isDev = process.argv.includes('--dev');
        this.projectRoot = path.join(__dirname, '..');
    }

    createWindow() {
        // Create the browser window
        this.mainWindow = new BrowserWindow({
            width: 1200,
            height: 800,
            minWidth: 800,
            minHeight: 600,
            webPreferences: {
                nodeIntegration: true,
                contextIsolation: false,
                enableRemoteModule: true
            },
            icon: path.join(__dirname, 'assets', 'icon.png'),
            show: false
        });

        // Load the app
        this.mainWindow.loadFile('src/index.html');

        // Show window when ready
        this.mainWindow.once('ready-to-show', () => {
            this.mainWindow.show();
            
            if (this.isDev) {
                this.mainWindow.webContents.openDevTools();
            }
        });

        // Handle window closed
        this.mainWindow.on('closed', () => {
            this.mainWindow = null;
        });
    }

    setupIPC() {
        // Handle app ready
        ipcMain.handle('app-ready', () => {
            return {
                projectRoot: this.projectRoot,
                version: require('./package.json').version
            };
        });

        // File operations
        ipcMain.handle('save-file', async (event, content, defaultName) => {
            try {
                const result = await dialog.showSaveDialog(this.mainWindow, {
                    defaultPath: defaultName,
                    filters: [
                        { name: 'JSON Files', extensions: ['json'] },
                        { name: 'Text Files', extensions: ['txt'] },
                        { name: 'All Files', extensions: ['*'] }
                    ]
                });

                if (!result.canceled) {
                    await fs.writeFile(result.filePath, content, 'utf8');
                    return { success: true, filePath: result.filePath };
                }
                return { success: false, canceled: true };
            } catch (error) {
                return { success: false, error: error.message };
            }
        });

        ipcMain.handle('load-file', async (event) => {
            try {
                const result = await dialog.showOpenDialog(this.mainWindow, {
                    filters: [
                        { name: 'JSON Files', extensions: ['json'] },
                        { name: 'Text Files', extensions: ['txt'] },
                        { name: 'All Files', extensions: ['*'] }
                    ],
                    properties: ['openFile']
                });

                if (!result.canceled && result.filePaths.length > 0) {
                    const content = await fs.readFile(result.filePaths[0], 'utf8');
                    return { 
                        success: true, 
                        content, 
                        filePath: result.filePaths[0],
                        fileName: path.basename(result.filePaths[0])
                    };
                }
                return { success: false, canceled: true };
            } catch (error) {
                return { success: false, error: error.message };
            }
        });

        // Q2Validate integration
        ipcMain.handle('run-q2validate', async (event, inputData, options = {}) => {
            return new Promise(async (resolve) => {
                try {
                    const q2validatePath = path.join(this.projectRoot, 'q2validate');
                    const scriptPath = path.join(q2validatePath, 'q2validate_cli.py');
                    
                    // Check if q2validate exists
                    if (!fs.existsSync(scriptPath)) {
                        resolve({
                            success: false,
                            error: `Q2Validate not found at ${scriptPath}`
                        });
                        return;
                    }

                    // Create temporary input file
                    const tempDir = path.join(__dirname, 'temp');
                    await fs.ensureDir(tempDir);
                    const tempInputFile = path.join(tempDir, `input_${Date.now()}.json`);
                    
                    await fs.writeFile(tempInputFile, JSON.stringify(inputData, null, 2));

                    // Build command arguments
                    const args = [scriptPath, tempInputFile];
                    if (options.verbose) args.push('--verbose');
                    if (options.noAutoFix) args.push('--no-auto-fix');
                    if (options.readyOnly) args.push('--ready-only');
                    
                    let tempOutputFile = null;
                    if (options.generateOutput) {
                        tempOutputFile = path.join(tempDir, `output_${Date.now()}.json`);
                        args.push('--output', tempOutputFile);
                    }

                    const process = spawn('python', args, {
                        cwd: q2validatePath,
                        stdio: ['pipe', 'pipe', 'pipe']
                    });

                    let stdout = '';
                    let stderr = '';

                    process.stdout.on('data', (data) => {
                        stdout += data.toString();
                    });

                    process.stderr.on('data', (data) => {
                        stderr += data.toString();
                    });

                    process.on('close', async (code) => {
                        try {
                            // Clean up temp input file
                            await fs.remove(tempInputFile);

                            let outputData = null;
                            if (tempOutputFile && await fs.pathExists(tempOutputFile)) {
                                const outputContent = await fs.readFile(tempOutputFile, 'utf8');
                                outputData = JSON.parse(outputContent);
                                await fs.remove(tempOutputFile);
                            }

                            if (code === 0) {
                                resolve({
                                    success: true,
                                    output: stdout,
                                    validatedData: outputData,
                                    validationPassed: true
                                });
                            } else {
                                resolve({
                                    success: true, // CLI ran, but validation failed
                                    output: stdout,
                                    error: stderr,
                                    validatedData: outputData,
                                    validationPassed: false
                                });
                            }
                        } catch (cleanupError) {
                            resolve({
                                success: false,
                                error: `Cleanup error: ${cleanupError.message}`,
                                output: stdout
                            });
                        }
                    });

                    process.on('error', (error) => {
                        resolve({
                            success: false,
                            error: `Failed to start q2validate: ${error.message}`
                        });
                    });

                } catch (error) {
                    resolve({
                        success: false,
                        error: `Error running q2validate: ${error.message}`
                    });
                }
            });
        });

        // Error reporting
        ipcMain.handle('submit-error-report', async (event, reportData) => {
            try {
                const reportsDir = path.join(__dirname, 'error-reports');
                await fs.ensureDir(reportsDir);
                
                const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
                const reportFile = path.join(reportsDir, `error-report-${timestamp}.json`);
                
                const fullReport = {
                    ...reportData,
                    timestamp: new Date().toISOString(),
                    appVersion: require('./package.json').version,
                    platform: process.platform,
                    arch: process.arch
                };
                
                await fs.writeFile(reportFile, JSON.stringify(fullReport, null, 2));
                
                return {
                    success: true,
                    reportId: `error-report-${timestamp}`,
                    reportPath: reportFile
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message
                };
            }
        });

        // Open external links
        ipcMain.handle('open-external', (event, url) => {
            shell.openExternal(url);
        });

        // Get system info
        ipcMain.handle('get-system-info', () => {
            return {
                platform: process.platform,
                arch: process.arch,
                nodeVersion: process.version,
                electronVersion: process.versions.electron,
                projectRoot: this.projectRoot
            };
        });
    }

    init() {
        // Handle app events
        app.whenReady().then(() => {
            this.createWindow();
            this.setupIPC();

            app.on('activate', () => {
                if (BrowserWindow.getAllWindows().length === 0) {
                    this.createWindow();
                }
            });
        });

        app.on('window-all-closed', () => {
            if (process.platform !== 'darwin') {
                app.quit();
            }
        });
    }
}

// Create and initialize the app
const q2App = new Q2DesktopApp();
q2App.init();
'@

Set-Content -Path $MainJsPath -Value $MainJsContent -Encoding UTF8
Write-Host "  ✅ Created: main.js" -ForegroundColor Green

# Create index.html (simplified version - you'll need to copy the full version from the artifact)
Write-Host "`n📄 Creating src/index.html..." -ForegroundColor Yellow
$IndexHtmlPath = Join-Path $AppDir "src\index.html"
$IndexHtmlContent = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Q2 Desktop - Question Generation & Validation</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            padding: 40px;
            text-align: center;
        }
        h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 20px;
        }
        .status {
            background: #d4edda;
            color: #155724;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎓 Q2 Desktop</h1>
        <div class="status">
            <h2>✅ Setup Complete!</h2>
            <p>The Q2 Desktop App structure has been created successfully.</p>
            <p><strong>Next Step:</strong> Copy the complete HTML interface from the Claude artifact to replace this placeholder.</p>
        </div>
        <div style="text-align: left; background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3>📋 To Complete Setup:</h3>
            <ol>
                <li>Replace this index.html with the full interface from the artifact</li>
                <li>Run: <code>npm install</code></li>
                <li>Run: <code>npm start</code> to launch the app</li>
            </ol>
        </div>
    </div>
</body>
</html>
'@

Set-Content -Path $IndexHtmlPath -Value $IndexHtmlContent -Encoding UTF8
Write-Host "  ✅ Created: src/index.html (placeholder)" -ForegroundColor Green

# Create basic icon files (placeholders)
Write-Host "`n🎨 Creating placeholder icon files..." -ForegroundColor Yellow

$IconPaths = @(
    (Join-Path $AppDir "assets\icon.png"),
    (Join-Path $AppDir "assets\icon.ico"),
    (Join-Path $AppDir "assets\icon.icns")
)

foreach ($IconPath in $IconPaths) {
    "# Placeholder icon file - replace with actual icon" | Set-Content -Path $IconPath -Encoding UTF8
    Write-Host "  ✅ Created: $($IconPath.Split('\')[-2..-1] -join '\')" -ForegroundColor Green
}

# Create .gitignore file
Write-Host "`n📄 Creating .gitignore..." -ForegroundColor Yellow
$GitIgnorePath = Join-Path $AppDir ".gitignore"
$GitIgnoreContent = @'
# Dependencies
node_modules/
npm-debug.log*

# Build outputs
dist/
*.tgz

# Runtime files
temp/
*.log

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/

# Error reports (contains sensitive data)
error-reports/
'@

Set-Content -Path $GitIgnorePath -Value $GitIgnoreContent -Encoding UTF8
Write-Host "  ✅ Created: .gitignore" -ForegroundColor Green

# Create README file
Write-Host "`n📄 Creating README.md..." -ForegroundColor Yellow
$ReadmePath = Join-Path $AppDir "README.md"
$ReadmeContent = @'
# Q2 Desktop App

Desktop application for Q2 workflow - prompt generation, validation, and Q2LMS integration.

## Setup

1. Install Node.js (https://nodejs.org/)
2. Run: `npm install`
3. Replace `src/index.html` with the complete interface from Claude
4. Run: `npm start`

## Scripts

- `npm start` - Run the app
- `npm run dev` - Run in development mode
- `npm run build-win` - Build Windows executable

## Project Structure

- `main.js` - Electron main process
- `src/index.html` - Application interface
- `assets/` - Icons and resources
- `temp/` - Temporary files (auto-created)
- `error-reports/` - Error reports (auto-created)
'@

Set-Content -Path $ReadmePath -Value $ReadmeContent -Encoding UTF8
Write-Host "  ✅ Created: README.md" -ForegroundColor Green

# Summary
Write-Host "`n🎉 Setup Complete!" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "📁 Q2 Desktop App created at: $AppDir" -ForegroundColor Cyan

Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. cd '$AppDir'" -ForegroundColor White
Write-Host "2. Replace src\index.html with the complete interface from the Claude artifact" -ForegroundColor White
Write-Host "3. npm install" -ForegroundColor White
Write-Host "4. npm start" -ForegroundColor White

Write-Host "`n📊 Directory Structure Created:" -ForegroundColor Yellow
Get-ChildItem -Path $AppDir -Recurse | ForEach-Object {
    $RelativePath = $_.FullName.Replace("$AppDir\", "")
    if ($_.PSIsContainer) {
        Write-Host "  📁 $RelativePath\" -ForegroundColor Cyan
    } else {
        Write-Host "  📄 $RelativePath" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Ready to proceed with Node.js installation and npm commands!" -ForegroundColor Green

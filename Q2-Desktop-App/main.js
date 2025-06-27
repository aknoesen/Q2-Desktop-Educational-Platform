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

        // Load prompt template files
        ipcMain.handle('load-prompt-file', async (event, filePath) => {
            try {
                if (!fs.existsSync(filePath)) {
                    return {
                        success: false,
                        error: `Prompt file not found: ${filePath}`
                    };
                }

                const content = await fs.readFile(filePath, 'utf8');
                return {
                    success: true,
                    content: content.trim(),
                    filePath: filePath
                };
            } catch (error) {
                return {
                    success: false,
                    error: error.message
                };
            }
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

        // Q2Prompt integration
        ipcMain.handle('run-q2prompt', async (event, prompt, options) => {
            return new Promise((resolve) => {
                try {
                    const q2promptPath = path.join(this.projectRoot, 'q2prompt');
                    const scriptPath = path.join(q2promptPath, 'q2prompt.py');
                    
                    // Check if q2prompt exists
                    if (!fs.existsSync(scriptPath)) {
                        resolve({
                            success: false,
                            error: `Q2Prompt not found at ${scriptPath}`
                        });
                        return;
                    }

                    const args = [scriptPath, '--prompt', prompt];
                    if (options.format) args.push('--format', options.format);
                    if (options.count) args.push('--count', options.count.toString());

                    const process = spawn('python', args, {
                        cwd: q2promptPath,
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

                    process.on('close', (code) => {
                        if (code === 0) {
                            resolve({
                                success: true,
                                output: stdout,
                                prompt: prompt,
                                options: options
                            });
                        } else {
                            resolve({
                                success: false,
                                error: stderr || `Process exited with code ${code}`,
                                output: stdout
                            });
                        }
                    });

                    process.on('error', (error) => {
                        resolve({
                            success: false,
                            error: `Failed to start q2prompt: ${error.message}`
                        });
                    });

                } catch (error) {
                    resolve({
                        success: false,
                        error: `Error running q2prompt: ${error.message}`
                    });
                }
            });
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
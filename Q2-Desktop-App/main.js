const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs').promises;
const { spawn } = require('child_process');

let mainWindow;

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1200,
        height: 800,
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false
        },
        icon: path.join(__dirname, 'assets', 'icon.png'), // Optional: add your app icon
        title: 'Q2QTI Desktop App'
    });

    mainWindow.loadFile('src/index.html');
    
    // Remove this line for production to hide dev tools
    // mainWindow.webContents.openDevTools();
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
    }
});

// File operations
ipcMain.handle('save-file', async (event, content, filters) => {
    try {
        const result = await dialog.showSaveDialog(mainWindow, {
            filters: filters || [
                { name: 'Text Files', extensions: ['txt'] },
                { name: 'All Files', extensions: ['*'] }
            ]
        });

        if (!result.canceled) {
            await fs.writeFile(result.filePath, content, 'utf8');
            return { success: true, filePath: result.filePath };
        }
        return { success: false, cancelled: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('load-prompt-file', async (event, filename) => {
    try {
        const projectRoot = path.dirname(__dirname);
        const filePath = path.join(projectRoot, 'q2prompt', filename);
        const content = await fs.readFile(filePath, 'utf8');
        return { success: true, content };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

// Q2Validate CLI integration - CLEAN VERSION
ipcMain.handle('run-q2validate', async (event, jsonData) => {
    try {
        const projectRoot = path.dirname(__dirname);
        const q2validatePath = path.join(projectRoot, 'q2validate');
        const scriptPath = path.join(q2validatePath, 'q2validate_cli.py');
        
        // Verify script exists
        try {
            await fs.access(scriptPath);
        } catch {
            throw new Error('Q2Validate script not found. Please ensure q2validate_cli.py exists.');
        }
        
        // Create temp directory
        const tempDir = path.join(__dirname, 'temp');
        try {
            await fs.mkdir(tempDir, { recursive: true });
        } catch (error) {
            if (error.code !== 'EEXIST') throw error;
        }
        
        // Create temporary files
        const timestamp = Date.now();
        const inputFile = path.join(tempDir, `input_${timestamp}.json`);
        const outputFile = path.join(tempDir, `output_${timestamp}.json`);
        
        // Write input data
        await fs.writeFile(inputFile, JSON.stringify(jsonData, null, 2), 'utf8');
        
        // Prepare Python command
        const pythonArgs = [
            scriptPath,
            inputFile,
            '--verbose',
            '--output',
            outputFile
        ];
        
        // Execute Python script
        const result = await new Promise((resolve, reject) => {
            const pythonProcess = spawn('python', pythonArgs, {
                cwd: q2validatePath,
                stdio: ['pipe', 'pipe', 'pipe']
            });
            
            let stdout = '';
            let stderr = '';
            
            pythonProcess.stdout.on('data', (data) => {
                stdout += data.toString();
            });
            
            pythonProcess.stderr.on('data', (data) => {
                stderr += data.toString();
            });
            
            pythonProcess.on('close', (code) => {
                if (code === 0) {
                    resolve({ stdout, stderr, code });
                } else {
                    reject(new Error(`Python process failed with code ${code}\nStderr: ${stderr}`));
                }
            });
            
            pythonProcess.on('error', (error) => {
                reject(new Error(`Failed to start Python process: ${error.message}`));
            });
        });
        
        // Read output file
        let outputData = null;
        try {
            const outputContent = await fs.readFile(outputFile, 'utf8');
            outputData = JSON.parse(outputContent);
        } catch (error) {
            console.warn('Could not read output file:', error.message);
        }
        
        // Clean up temporary files
        try {
            await fs.unlink(inputFile);
            if (outputData) await fs.unlink(outputFile);
        } catch (error) {
            console.warn('Cleanup warning:', error.message);
        }
        
        // Parse results from stdout
        const parseResults = (output) => {
            const lines = output.split('\n');
            const results = {
                totalQuestions: 0,
                schemaValid: 0,
                unicodeIssues: 0,
                unicodeFixed: 0,
                readyForQ2LMS: 0,
                successRate: 0,
                status: 'UNKNOWN',
                issues: []
            };
            
            // Extract key metrics
            lines.forEach(line => {
                if (line.includes('Total Questions:')) {
                    results.totalQuestions = parseInt(line.split(':')[1].trim()) || 0;
                }
                if (line.includes('Schema Valid:')) {
                    results.schemaValid = parseInt(line.split(':')[1].trim()) || 0;
                }
                if (line.includes('Unicode Issues Found:')) {
                    results.unicodeIssues = parseInt(line.split(':')[1].trim()) || 0;
                }
                if (line.includes('Unicode Issues Fixed:')) {
                    results.unicodeFixed = parseInt(line.split(':')[1].trim()) || 0;
                }
                if (line.includes('Ready for Q2LMS:')) {
                    results.readyForQ2LMS = parseInt(line.split(':')[1].trim()) || 0;
                }
                if (line.includes('Success Rate:')) {
                    results.successRate = parseFloat(line.split(':')[1].replace('%', '').trim()) || 0;
                }
                if (line.includes('✅ SUCCESS:') || line.includes('SUCCESS:')) {
                    results.status = 'SUCCESS';
                }
                if (line.includes('⚠️ PARTIAL:') || line.includes('PARTIAL:')) {
                    results.status = 'PARTIAL';
                }
                if (line.includes('❌ FAILED:') || line.includes('FAILED:')) {
                    results.status = 'FAILED';
                }
            });
            
            return results;
        };
        
        const parsedResults = parseResults(result.stdout);
        
        return {
            success: true,
            results: parsedResults,
            outputData: outputData,
            rawOutput: result.stdout // Keep for troubleshooting if needed
        };
        
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
});
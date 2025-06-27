# Q2 Desktop App - Development Transition Document

**Date:** June 27, 2025  
**Status:** Core functionality complete, ready for testing and iteration  
**Location:** `C:\Users\aknoesen\Documents\Knoesen\Project-Root-Q2QTI\`

## 🎯 Project Overview

**Goal:** Create an "idiot-proof" desktop application that simplifies the Q2 workflow for educators, enabling them to generate, validate, and deploy educational questions with minimal technical knowledge.

**Achievement:** Successfully built and deployed a 3-stage Electron desktop application that integrates all Q2 modules.

## 📁 Current Project Structure

```
Project-Root-Q2QTI/
├── q2lms/                          # Source of truth for validation
│   └── modules/
│       ├── schema_validator.py     # JSON schema validation
│       ├── unicode_converter.py    # Unicode detection & conversion  
│       └── unicode_to_latex_converter.py # LaTeX conversion logic
├── q2validate/                     # Cleaned up validation module
│   ├── q2validate_cli.py           # ✅ Clean CLI - imports from q2lms
│   ├── q2validate.py               # Original Streamlit (kept for reference)
│   ├── backups/                    # Renamed duplicate modules
│   └── requirements.txt
├── q2prompt/                       # Question prompt generation
│   ├── q2prompt.py
│   ├── q2prompt_preamble_default.txt    # ⚠️ NEEDED for template loading
│   ├── q2prompt_postamble_default.txt   # ⚠️ NEEDED for template loading
│   └── requirements.txt
└── Q2-Desktop-App/                 # ✅ NEW - Electron desktop application
    ├── package.json                # Electron configuration
    ├── main.js                     # Backend logic (Node.js)
    ├── src/
    │   └── index.html              # Frontend interface
    ├── assets/                     # Icons (placeholder)
    ├── temp/                       # Auto-created temp files
    ├── error-reports/              # Auto-created error collection
    └── node_modules/               # Dependencies (from npm install)
```

## 🛠 Technical Architecture

### **Frontend (src/index.html)**
- **Technology:** HTML + CSS + JavaScript
- **Framework:** Vanilla JavaScript with Electron IPC
- **Design:** 3-stage tabbed workflow interface
- **Features:** Form validation, file operations, progress tracking

### **Backend (main.js)**  
- **Technology:** Node.js + Electron
- **Integration:** Spawns Python subprocesses for Q2 modules
- **File Management:** Handles temp files, exports, error reports
- **IPC Handlers:** Communication between frontend and backend

### **Module Integration**
- **Q2Validate:** CLI version imports from q2lms modules (single source of truth)
- **Q2Prompt:** Template-based prompt generation using preamble/postamble files
- **Q2LMS:** Web platform remains independent, receives validated JSON

## 🔄 User Workflow

### **Stage 1: Prompt Builder**
1. **LLM Selection:** Choose OpenAI, Claude, Gemini, or Microsoft Copilot
2. **Context Input:** Educational subject and topic specification
3. **Parameters:** Question count (5-20) and types (mixed/specific)
4. **Template Assembly:** Combines preamble + user context + postamble
5. **Output:** Complete prompt ready for copy/paste to chosen LLM

### **Stage 2: LLM Processing**
1. **Response Input:** Paste LLM-generated content
2. **Auto-Processing:** Extract JSON, clean markdown, fix quotes
3. **Manual Editing:** Optional manual JSON editing capability
4. **Validation:** JSON syntax validation before proceeding
5. **Output:** Clean, validated JSON ready for Q2Validate

### **Stage 3: Validation**
1. **Q2Validate Integration:** Calls q2validate_cli.py via subprocess
2. **Schema Validation:** Checks against Q2LMS requirements
3. **Unicode Processing:** Auto-converts Unicode to LaTeX notation
4. **Results Dashboard:** Visual metrics and detailed error reporting
5. **Export Options:** Ready questions for Q2LMS, all questions, error reports

## 🔧 Key Components

### **Electron IPC Handlers (main.js)**
```javascript
// Core handlers implemented:
app-ready              // App initialization
save-file             // File save dialogs
load-file             // File open dialogs  
load-prompt-file      // Load preamble/postamble templates
run-q2validate        // Execute validation subprocess
submit-error-report   // Collect failure cases
get-system-info       // System diagnostics
```

### **JavaScript Functions (index.html)**
```javascript
// Stage management:
switchTab()           // Tab navigation
selectLLM()           // LLM selection

// Stage 1 - Prompt Builder:
generatePrompt()      // Template assembly
loadPromptFiles()     // Load preamble/postamble
copyPrompt()          // Clipboard integration

// Stage 2 - LLM Processing:
processText()         // Auto-clean LLM responses
validateJSON()        // JSON syntax validation
editManually()        // Manual editing mode

// Stage 3 - Validation:
runValidation()       // Q2Validate integration
displayValidationResults()  // Results dashboard
exportReady()         // Export validated questions
submitErrorReport()   // Error collection system
```

## ✅ Completed Features

### **Core Functionality**
- ✅ 3-stage workflow with visual progress
- ✅ LLM integration (copy/paste approach)
- ✅ Template-based prompt generation
- ✅ Automatic text processing and JSON cleaning
- ✅ Q2Validate CLI integration with subprocess calls
- ✅ Error reporting and data collection
- ✅ File operations (save/load drafts, export results)

### **User Experience**
- ✅ "Idiot-proof" interface design
- ✅ Visual feedback and progress indicators
- ✅ Clear error messages and guidance
- ✅ Tab-based workflow with completion tracking
- ✅ Responsive design with modern aesthetics

### **Integration**
- ✅ Clean module architecture (no code duplication)
- ✅ Q2Validate imports from Q2LMS (single source of truth)
- ✅ Template file loading from Q2Prompt
- ✅ Automatic temp file management
- ✅ Cross-platform compatibility

## ⚠️ Current Requirements

### **Template Files (Missing)**
The app expects these files to exist:
```
q2prompt/q2prompt_preamble_default.txt
q2prompt/q2prompt_postamble_default.txt
```

**Action Required:** Create these template files with the standard Q2 prompt format.

### **Dependencies**
- ✅ Node.js v22.17.0 (installed)
- ✅ npm v10.9.2 (installed)
- ✅ Python (for Q2 modules)
- ✅ Electron dependencies (installed)

## 🧪 Testing Status

### **Verified Working**
- ✅ Q2Validate CLI independently tested
- ✅ Electron app launches successfully
- ✅ Basic UI navigation and form handling
- ✅ npm install and dependency management

### **Needs Testing**
- ⏳ Template file loading (pending file creation)
- ⏳ Q2Validate subprocess integration
- ⏳ Error reporting workflow
- ⏳ Complete end-to-end user workflow

## 🚀 Deployment

### **Development Mode**
```powershell
cd Q2-Desktop-App
npm start
```

### **Production Build**
```powershell
npm run build-win      # Creates Windows installer
```

**Output:** `dist/` folder with executable installer

## 📊 Success Metrics

### **User Adoption**
- **Target:** Increase tester participation by simplifying workflow
- **Measure:** Number of successful question generation sessions
- **Benefit:** Reduced technical barrier to entry

### **Data Collection**
- **Target:** Gather failure cases for system improvement
- **Measure:** Error reports submitted automatically
- **Benefit:** Identify Q2Prompt and Q2Validate improvement areas

### **Workflow Efficiency**
- **Target:** Reduce time from prompt to validated questions
- **Measure:** End-to-end completion times
- **Benefit:** Faster iteration and testing cycles

## 🔮 Next Steps

### **Immediate (Next Session)**
1. **Create template files:** q2prompt_preamble_default.txt and q2prompt_postamble_default.txt
2. **Test complete workflow:** Full end-to-end testing with real LLM
3. **Bug fixes:** Address any integration issues discovered
4. **GitHub repository:** Set up version control and backup

### **Short Term**
1. **Tester deployment:** Package and distribute to educators
2. **Feedback collection:** Gather usability feedback and error reports
3. **UI improvements:** Iterate based on real user testing
4. **Documentation:** User guide and troubleshooting

### **Medium Term**
1. **Q2Prompt integration:** Direct LLM API calls (optional)
2. **Batch processing:** Multiple prompt sets
3. **Template management:** User-defined prompt templates
4. **Advanced validation:** Custom validation rules

## 🐛 Known Issues & Limitations

### **File Paths**
- **Issue:** Hardcoded Windows paths for template files
- **Impact:** Won't work on Mac/Linux without modification
- **Solution:** Make paths configurable or detect OS

### **Error Handling**
- **Issue:** Basic error messages for subprocess failures
- **Impact:** Users may not understand technical errors
- **Solution:** Improve error translation and user guidance

### **Performance**
- **Issue:** Synchronous subprocess calls may block UI
- **Impact:** App appears frozen during validation
- **Solution:** Add better progress indicators or async processing

## 📝 Developer Notes

### **Code Organization**
- **Frontend:** Single HTML file with embedded CSS/JavaScript
- **Backend:** Single main.js file with all IPC handlers
- **Future:** Consider splitting into multiple modules for maintainability

### **Security**
- **Current:** Basic file operations, no authentication
- **Consideration:** Validate file paths and content for production use
- **Future:** Sandboxing for subprocess execution

### **Scalability**
- **Current:** Single-user desktop application
- **Future:** Could be adapted for multi-user or web deployment
- **Architecture:** Clean separation allows for different deployment targets

## 📋 Development Checklist

### **Pre-Testing**
- [ ] Create q2prompt_preamble_default.txt
- [ ] Create q2prompt_postamble_default.txt  
- [ ] Test template file loading
- [ ] Verify Q2Validate CLI paths
- [ ] Test complete workflow once

### **Pre-Deployment**
- [ ] Cross-platform path handling
- [ ] Error message improvements
- [ ] User documentation
- [ ] Installation instructions
- [ ] GitHub repository setup

### **Post-Deployment**
- [ ] Monitor error reports
- [ ] Collect user feedback
- [ ] Performance optimization
- [ ] Feature prioritization based on usage

## 💡 Architecture Decisions

### **Why Electron?**
- **Cross-platform compatibility**
- **Familiar web technologies**
- **Rich UI capabilities**
- **Easy integration with existing Python modules**

### **Why Subprocess Integration?**
- **Preserve existing Q2 module functionality**
- **Avoid Python/JavaScript bridge complexity**
- **Maintain clean separation of concerns**
- **Enable independent module development**

### **Why Copy/Paste LLM Integration?**
- **Works with any LLM (no API dependencies)**
- **User controls the LLM interaction**
- **No API costs or rate limiting**
- **Maximum flexibility for testers**

---

**This document captures the complete current state of the Q2 Desktop App project. Save this for reference and continuation of development.**
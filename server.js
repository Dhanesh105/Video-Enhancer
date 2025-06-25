const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');

const app = express();
const port = 3000;

// --- Directory Setup ---
const uploadsDir = path.join(__dirname, 'uploads');
const outputsDir = path.join(__dirname, 'outputs');
const publicDir = path.join(__dirname, 'public');

// Create directories if they don't exist
[uploadsDir, outputsDir].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// --- Middleware ---
app.use(express.static(publicDir));

// --- Multer Setup for File Uploads ---
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadsDir);
    },
    filename: (req, file, cb) => {
        // Use a unique name to avoid conflicts
        cb(null, `${Date.now()}-${file.originalname}`);
    }
});
const upload = multer({ storage: storage });

// --- Routes ---
app.get('/', (req, res) => {
    res.sendFile(path.join(publicDir, 'index.html'));
});

app.post('/upload', upload.single('video'), (req, res) => {
    if (!req.file) {
        return res.status(400).send('No file uploaded.');
    }

    const inputFile = req.file.path;
    const outputFileName = `enhanced-${req.file.filename}`;
    const outputFile = path.join(outputsDir, outputFileName);

    // IMPORTANT: Ensure the 'matlab' command is in your system's PATH.
    // The -batch flag runs the script without starting the MATLAB desktop.
    const matlabCommand = `matlab -batch "processVideo('${inputFile}', '${outputFile}')"`;

    console.log(`Executing: ${matlabCommand}`);

    exec(matlabCommand, (error, stdout, stderr) => {
        if (error) {
            console.error(`MATLAB Error: ${error.message}`);
            console.error(`MATLAB stderr: ${stderr}`);
            // Clean up the uploaded file
            fs.unlink(inputFile, (err) => {
                if (err) console.error(`Failed to delete input file: ${err}`);
            });
            return res.status(500).send(`Error during video processing: ${stderr || error.message}`);
        }

        console.log(`MATLAB stdout: ${stdout}`);

        // Send the processed file for download
        res.download(outputFile, outputFileName, (err) => {
            if (err) {
                console.error(`Download Error: ${err.message}`);
            }

            // --- Cleanup ---
            // Delete the original uploaded file and the processed output file
            fs.unlink(inputFile, (unlinkErr) => {
                if (unlinkErr) console.error(`Failed to delete input file: ${inputFile}`);
            });
            fs.unlink(outputFile, (unlinkErr) => {
                if (unlinkErr) console.error(`Failed to delete output file: ${outputFile}`);
            });
        });
    });
});

// --- Server Start ---
app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
    console.log('Make sure MATLAB is installed and the `matlab` command is in your system PATH.');
});

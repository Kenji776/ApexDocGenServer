// server.js: Node.js backend to handle file uploads and processing
const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { processFiles } = require("./generateDocs"); // Modularized generateDocs.js

const app = express();
const PORT = 3500;

// Logging utility
const logFile = path.join(__dirname, "server.log");
function logEvent(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  console.log(logMessage.trim());
  fs.appendFileSync(logFile, logMessage);
}

// Generate a unique folder name for each batch upload
function generateUniqueFolderName() {
  return `uploads/${Date.now()}_${Math.random()
    .toString(36)
    .substring(2, 15)}`;
}

// Middleware to create a unique folder for each upload batch
function createUploadFolder(req, res, next) {
  const uniqueFolder = generateUniqueFolderName();
  req.uploadBase = uniqueFolder; // Base directory for this batch
  req.uploadFolder = path.join(uniqueFolder, "Source");
  req.markdownFolder = path.join(uniqueFolder, "markdown");
  req.htmlFolder = path.join(uniqueFolder, "html");
  req.outputFolder = path.join(uniqueFolder, "output");

  [req.uploadFolder, req.markdownFolder, req.htmlFolder, req.outputFolder].forEach((folder) => {
    if (!fs.existsSync(folder)) {
      fs.mkdirSync(folder, { recursive: true });
    }
  });

  logEvent(`Created unique folder for upload: ${uniqueFolder}`);
  next();
}

// Set up storage for multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, req.uploadFolder); // Use the unique folder for all files in this batch
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname); // Retain original file name and extension
  },
});
const upload = multer({ storage });

// Serve the frontend
app.use(express.static("public"));

// Endpoint to upload files
app.post(
  "/upload",
  createUploadFolder,
  upload.array("files"),
  async (req, res) => {
    logEvent("Received upload request.");

    if (!req.files || req.files.length === 0) {
      logEvent("No files uploaded.");
      return res.status(400).send("No files uploaded.");
    }

    const filePaths = req.files.map((file) =>
      path.join(req.uploadFolder, file.filename)
    );

    try {
      logEvent(`Processing files: ${filePaths.join(", ")}`);
      const zipFilePath = await processFiles(
        req.uploadFolder,
        req.markdownFolder,
        req.htmlFolder,
        req.outputFolder
      );
      logEvent(`Processing complete. Zip file created at: ${zipFilePath}`);
      res.json({ downloadLink: `/${zipFilePath}` });
    } catch (error) {
      logEvent(`Error processing files: ${error.message}`);
      res.status(500).send("An error occurred while processing files.");
    }
  }
);

// Serve the processed files for download
app.use("/uploads", express.static("uploads"));

// Error logging middleware
app.use((err, req, res, next) => {
  logEvent(`Unhandled error: ${err.message}`);
  res.status(500).send("An unexpected error occurred.");
});

// Start the server
app.listen(PORT, () => {
  logEvent(`Server running at http://localhost:${PORT}`);
});

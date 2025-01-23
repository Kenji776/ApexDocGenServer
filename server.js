const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const { processFiles } = require("./generateDocs");

const app = express();
// Use the environment-provided port or default to 3000
const PORT = process.env.PORT || 3000;
const UPLOAD_DIR = path.join(__dirname, "uploads");
const POLL_INTERVAL = 24 * 60 * 60 * 1000; // 24 hours
const EXPIRATION_DAYS = 10;
const EXPIRATION_TIME = EXPIRATION_DAYS * 24 * 60 * 60 * 1000;

// Logging utility
const logFile = path.join(__dirname, "server.log");
function logEvent(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  console.log(logMessage.trim());
  fs.appendFileSync(logFile, logMessage);
}

// Set up storage for multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const folderName = `${Date.now()}_${Math.random()
      .toString(36)
      .substr(2, 10)}`;
    const uploadPath = path.join(UPLOAD_DIR, folderName, "source");

    fs.mkdirSync(uploadPath, { recursive: true });
    logEvent(`Created upload folder structure: ${uploadPath}`);
    req.uploadPath = path.dirname(uploadPath);
    cb(null, uploadPath);
  },
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  },
});
const upload = multer({ storage });

// Serve the frontend
app.use(express.static("public"));

// Endpoint to upload files
app.post("/upload", upload.array("files"), async (req, res) => {
  logEvent("Received upload request.");

  if (!req.files || req.files.length === 0) {
    logEvent("No files uploaded.");
    return res.status(400).send("No files uploaded.");
  }

  const sourceDir = path.join(req.uploadPath, "source");
  const markdownDir = path.join(req.uploadPath, "markdown");
  const htmlDir = path.join(req.uploadPath, "html");
  const outputDir = path.join(req.uploadPath, "output");

  try {
    logEvent(`Processing files in folder: ${sourceDir}`);
    const zipFilePath = await processFiles(
      sourceDir,
      markdownDir,
      htmlDir,
      outputDir
    );
    logEvent(`Processing complete. Zip file created at: ${zipFilePath}`);
    res.json({
      downloadLink: `/uploads/${path.basename(
        req.uploadPath
      )}/output/${path.basename(zipFilePath)}`,
    });
  } catch (error) {
    logEvent(`Error processing files: ${error.message}`);
    res.status(500).send("An error occurred while processing files.");
  }
});

// Serve the processed files for download
app.use("/uploads", express.static(UPLOAD_DIR));

// Poller to delete old folders
function deleteOldUploads() {
  logEvent("Running upload folder cleanup poller.");

  const now = Date.now();
  fs.readdir(UPLOAD_DIR, (err, folders) => {
    if (err) {
      logEvent(`Error reading upload directory: ${err.message}`);
      return;
    }

    folders.forEach((folder) => {
      const folderPath = path.join(UPLOAD_DIR, folder);
      fs.stat(folderPath, (err, stats) => {
        if (err) {
          logEvent(
            `Error reading folder stats: ${folderPath} - ${err.message}`
          );
          return;
        }

        if (now - stats.mtimeMs > EXPIRATION_TIME) {
          fs.rm(folderPath, { recursive: true, force: true }, (err) => {
            if (err) {
              logEvent(`Error deleting folder: ${folderPath} - ${err.message}`);
            } else {
              logEvent(`Deleted old folder: ${folderPath}`);
            }
          });
        }
      });
    });
  });
}

// Start the poller
setInterval(deleteOldUploads, POLL_INTERVAL);

// Error logging middleware
app.use((err, req, res, next) => {
  logEvent(`Unhandled error: ${err.message}`);
  res.status(500).send("An unexpected error occurred.");
});

// Start the server
app.listen(PORT, () => {
  logEvent(`Server running at http://localhost:${PORT}`);
});

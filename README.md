# ApexDocs Generator Utility

## Overview

This utility is a Node.js application that allows users to upload Salesforce Apex class files and their corresponding metadata XML files. It processes the uploaded files to generate Markdown and HTML documentation using the [ApexDocs](https://github.com/cesarParra/apexdocs) utility. The final output, including the generated files, is packaged into a ZIP archive for download.

## Features

- **File Validation**: Ensures uploaded files are valid `.cls` files with corresponding `.cls-meta.xml` files.
- **Markdown and HTML Generation**: Converts Apex class files into Markdown and HTML documentation.
- **Theme Support**: Generated HTML files include a style picker to switch between multiple themes.
- **Credits**: Acknowledges the original creator of ApexDocs.

## How to Use

1. **Upload Files**:
   - Navigate to the application in your web browser.
   - Drag and drop or select the `.cls` and `.cls-meta.xml` files for upload.
   - Ensure every `.cls` file has a corresponding `.cls-meta.xml` file.
   
2. **Processing**:
   - Click the "Upload and Process" button.
   - The system will validate, process, and generate documentation.

3. **Download Results**:
   - Once processing is complete, a download link for the ZIP archive will be displayed.
   - Click the link to download the documentation.

## Requirements

- Node.js (v16 or higher)
- ApexDocs installed and accessible from the command line

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Kenji776/ApexDocGenServer
2. Install dependencies
    ```bash
    npm install
3. Start the server
    ```bash
    node server.js
4. Open your browser to http://localhost:3500

## Configuration
The server listens on port 3500 by default. You can change the port by setting the PORT environment variable.


## Formatting Your Apex Code for ApexDocs

To get the best output from the ApexDocs package, format your Apex code using the Javadoc style for class and method documentation. Below is a basic example:

### Example Apex Class with Documentation
```apex
/**
 * @description This class contains utility methods for attendance processing.
 * @author John Doe
 * @date 2025-01-23
 */
public class AttendanceUtilities {

    /**
     * @description Calculates the total number of students present.
     * @param attendanceList List<Boolean> - A list where each element represents whether a student is present.
     * @return Integer - The total count of students present.
     */
    public static Integer calculatePresent(List<Boolean> attendanceList) {
        Integer count = 0;
        for (Boolean isPresent : attendanceList) {
            if (isPresent) {
                count++;
            }
        }
        return count;
    }

    /**
     * @description Fetches the names of students who were absent.
     * @param studentNames List<String> - A list of student names.
     * @param attendanceList List<Boolean> - A list where each element represents whether a student is present.
     * @return List<String> - A list of names of absent students.
     */
    public static List<String> getAbsentStudents(List<String> studentNames, List<Boolean> attendanceList) {
        List<String> absentees = new List<String>();
        for (Integer i = 0; i < studentNames.size(); i++) {
            if (!attendanceList[i]) {
                absentees.add(studentNames[i]);
            }
        }
        return absentees;
    }
}

# ApexDocs Generator Utility

## Overview

This utility is a Node.js application that allows users to upload Salesforce Apex class files and their corresponding metadata XML files. It processes the uploaded files to generate Markdown and HTML documentation using the [ApexDocs](https://github.com/cesarParra/apexdocs) utility. The final output, including the generated files, is packaged into a ZIP archive for download.

## Features

- **File Validation**: Ensures uploaded files are valid `.cls` files with corresponding `.cls-meta.xml` files.
- **Markdown and HTML Generation**: Converts Apex class files into Markdown and HTML documentation.
- **Theme Support**: Generated HTML files include a style picker to switch between multiple themes.

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

To get the best output from the ApexDocs package, format your Apex code using the Javadoc style for class and method documentation. Below is a basic example, see https://github.com/cesarParra/apexdocs/wiki/2.-%F0%9F%93%96-Documenting-Apex-code for more in depth explanations.

### Example Apex Class with Documentation
```apex
/**
 * @Name DemoApexClass
 * @Author Kenji776
 * @Date 2024-10-13
 * @Description This is a sample Apex class demonstrating how to document methods using Javadoc-style annotations. 
 * The class includes methods for inserting a Contact, querying Contacts, performing basic math, and updating a record.
 * @Group DocumentationDemo
 */
public with sharing class DemoApexClass {

    /**
     * @Description Inserts a new Contact record into the system.
     * @Param firstName The first name of the Contact.
     * @Param lastName The last name of the Contact.
     * @Return The inserted Contact record.
     */
    public static Contact createContact(String firstName, String lastName) {
        Contact newContact = new Contact(
            FirstName = firstName,
            LastName = lastName
        );
        insert newContact;
        return newContact;
    }

    /**
     * @Description Queries Contacts based on a last name.
     * @Param lastName The last name to filter Contacts by.
     * @Return A list of Contacts matching the specified last name.
     */
    public static List<Contact> getContactsByLastName(String lastName) {
        return [SELECT Id, FirstName, LastName FROM Contact WHERE LastName = :lastName];
    }

    /**
     * @Description Performs a basic mathematical operation (addition).
     * @Param a The first number.
     * @Param b The second number.
     * @Return The sum of the two numbers.
     */
    public static Integer addNumbers(Integer a, Integer b) {
        return a + b;
    }

    /**
     * @Description Updates the first name of a Contact.
     * @Param contactId The ID of the Contact to update.
     * @Param newFirstName The new first name to set.
     * @Return Boolean indicating success or failure.
     */
    public static Boolean updateContactFirstName(Id contactId, String newFirstName) {
        Contact c = [SELECT Id, FirstName FROM Contact WHERE Id = :contactId LIMIT 1];
        if (c != null) {
            c.FirstName = newFirstName;
            update c;
            return true;
        }
        return false;
    }
}

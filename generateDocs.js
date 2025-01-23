// Modularized generateDocs.js
const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");
const baseTheme = "markdown8";

// Logging utility
const logFile = path.join(__dirname, "generateDocs.log");
function logEvent(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  console.log(logMessage.trim());
  fs.appendFileSync(logFile, logMessage);
}

async function processFiles(sourceDir, markdownDir, htmlDir, outputDir) {
  logEvent(
    `Starting file processing with source: ${sourceDir}, markdown: ${markdownDir}, html: ${htmlDir}, output: ${outputDir}`
  );

  // Ensure Markdown, HTML, and output directories exist
  if (!fs.existsSync(markdownDir)) {
    fs.mkdirSync(markdownDir, { recursive: true });
  }
  if (!fs.existsSync(htmlDir)) {
    fs.mkdirSync(htmlDir, { recursive: true });
  }
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  try {
    // Step 1: Generate Markdown files using apexdocs
    logEvent("Generating Markdown files.");
    await runCommand(
      `apexdocs markdown -p global public private protected namespaceaccessible -s "${sourceDir}" -t "${markdownDir}"`
    );
    logEvent(`Generated Markdown files for directory: ${sourceDir}`);

    // Step 2: Generate HTML files from Markdown recursively
    logEvent("Generating HTML files from Markdown recursively.");
    await processMarkdownRecursively(markdownDir, htmlDir);

    // Step 3: Copy the themes folder to the HTML folder
    logEvent("Copying themes folder to the HTML directory.");
    const themesSourcePath = path.join(__dirname, "themes");
    const themesDestPath = path.join(htmlDir, "themes");

    if (!fs.existsSync(themesSourcePath)) {
      throw new Error("Themes folder not found in project root.");
    }

    fs.cpSync(themesSourcePath, themesDestPath, { recursive: true });
    logEvent(`Themes folder copied to: ${themesDestPath}`);

    // Step 4: Fix the generated HTML files
    logEvent("Fixing generated HTML files.");
    fixHtml(htmlDir);

    // Step 5: Zip the contents of the Markdown and HTML folders
    const outputZipPath = path.join(outputDir, "output.zip");
    logEvent("Zipping processed files.");
    await zipOutput(sourceDir, markdownDir, htmlDir, outputZipPath);

    logEvent(`Processing complete. Output zip created at: ${outputZipPath}`);
    return outputZipPath;
  } catch (error) {
    logEvent(`Error during file processing: ${error.message}`);
    throw error;
  }
}

async function processMarkdownRecursively(markdownDir, htmlDir) {
  const items = fs.readdirSync(markdownDir);

  for (const item of items) {
    const itemPath = path.join(markdownDir, item);
    const itemHtmlPath = path.join(htmlDir, item);
    const stats = fs.statSync(itemPath);

    if (stats.isDirectory()) {
      if (!fs.existsSync(itemHtmlPath)) {
        fs.mkdirSync(itemHtmlPath, { recursive: true });
      }
      await processMarkdownRecursively(itemPath, itemHtmlPath);
    } else if (item.endsWith(".md")) {
      const htmlFilePath = itemHtmlPath.replace(/\.md$/, ".html");
      await runCommand(
        `markdown "${itemPath}" -s ${baseTheme} > "${htmlFilePath}"`
      );
      logEvent(`Generated HTML for: ${itemPath}`);
    }
  }
}

function zipOutput(sourceDir, markdownDir, htmlDir, targetZipPath) {
  return new Promise((resolve, reject) => {
    const sources = [
      `"${sourceDir}/*"`,
      `"${markdownDir}/*"`,
      `"${htmlDir}/*"`,
    ].join(" ");
    exec(
      `7z a "${targetZipPath}" ${sources} -r -tzip`,
      (error, stdout, stderr) => {
        if (error) {
          logEvent(`Error creating zip: ${stderr}`);
          return reject(error);
        }
        logEvent(`Zip created successfully: ${targetZipPath}`);
        resolve(stdout);
      }
    );
  });
}

/**
* @Description modifies all the markdown files in the markdown folder to fix the links as well as modify the HTML to inject the stylesheet chooser and fix other small errors/issues with the generated HTML.
* @Param sourceDirectory a string of the source directory to evaluate all HTML files in
* @Param sourceType For all links that point to this file extensions, change them to the targetType type. Ex change all links that point to '.md' files to '.html' files which is needed after conversion from markdown to html.
* @Param targetType the file of file extension to change all the sourceType links to.
* @Return void
*/
function fixHtml(directory) {
  const filesToModify = getFilesRecursively(directory, ["html"]);

  logEvent("Fixing HTML files");

  for (const fileName of filesToModify) {
    try {
      logEvent(`Processing HTML in file: ${fileName}`);
      const fileContents = fs.readFileSync(fileName, "utf-8");

      let newFile = fileContents.replaceAll(".md", ".html");
      newFile = newFile.replaceAll(
        "<body>",
        `<body><link rel="stylesheet" type="text/css" href="${baseTheme}.css" id="_theme"><div id="_html" class="markdown-body">` +
          injectStylePicker(baseTheme)
      );
      newFile = newFile.replaceAll("</body>", "</div></body>");
      newFile = newFile.replaceAll(
        '<h2 id="layout-default">layout: default</h2>',
        ""
      );
      newFile = newFile.replaceAll('href="/', 'href="');
      newFile = unescapeHTML(newFile);

      // Synchronously write the fixed HTML to avoid conflicts
      fs.writeFileSync(fileName, newFile);
      logEvent(`HTML fixed for file: ${fileName}`);
    } catch (err) {
      logEvent(`Error fixing HTML in file: ${fileName} - ${err.message}`);
    }
  }

  logEvent("HTML fixing complete.");
}


/**
* @Description Generates the HTML to inject into each of the generated HTML pages that allows the user to select which style they would like to use. It does this by iterating over
* all the css files in the themes directory. Since the HTML files will not know where the themes directory is (they may be anywhere lower in the directory structure) and there is 
* no absolute path since these documents may be moved between different computers the approach is to read the current file path from the href and check it folder by folder for the
* 'themes' folder that contains the defaultStyle css file. It will attempt to do this starting from the 3rd folder (EX C:/users/apexDoc/docs/index.html would start at apexDoc) and 
* then sequentially check each folder until the theme is found or the path is exhaused.
* In the future will also inject a cookie to remember users preferences. Also may update to include the JS in a seperate JS file to reduce duplication. 
* @Param defaultStyle Name of css file to use as the selected default.
* @Return void
*/
function injectStylePicker(defaultStyle){

	defaultStyle += '.css';
	let themes = getFilesRecursively('themes', ['css']);
	let themeString = '';

	themes.forEach((themeFile) => {
		var themeNameParts = themeFile.split('\\');
		var themeFileName = themeNameParts[themeNameParts.length-1];
		var themeName = themeFileName.split('.')[0];

		themeString += `<option value="${themeFileName}">${themeName}</option>`
	});

	const injectHtml = `
		<script>
		let folderIndex = 3;
		let urlParts = window.location.href.split('/');
		let cssPath;
		let currentUrl = urlParts[0];
		let loadMisses = 0;
		function setCssPath(src){
			src = src.replace('${defaultStyle}','');
			cssPath = src;

			const styleChooser = document.getElementById('styleChooser');
			styleChooser.style.display = 'block';

			const styleLoader = document.getElementById('styleLoader');
			styleLoader.style.display = 'none';

			var sel = document.getElementById('style_select').value = '${defaultStyle}';
			changeSheet('${defaultStyle}');
		}
		function handleLoadMiss(src){
			loadMisses++;
			if(loadMisses >= urlParts.length){
				const styleLoaderError = document.getElementById('styleLoadError');
				styleLoaderError.style.display = 'block';				
			}
		}

		while(folderIndex<urlParts.length){
			currentUrl +='/'+ urlParts[folderIndex];
			let el=document.createElement('script');
			el.id="sheet"+folderIndex;
			el.src=currentUrl+'/themes/${defaultStyle}';
			el.onload=function(){if(el.onload)setCssPath(this.src)}
			el.onerror=function(){if(el.onerror)handleLoadMiss(this.src)}
			document.body.appendChild(el);
			folderIndex++;
		}

		function handleStyleSelectChange(selectObject){
			 changeSheet(selectObject.value)
		}
		function changeSheet(sheetName){
			[...document.getElementsByTagName("link")].forEach((rel) => {
				rel.setAttribute("href", cssPath+'/'+sheetName);  
			});
		}
		</script>

		<div style="float:right" id="styleLoader">
			<b>Finding Styles. Please Wait</b>
		</div>
		<div style="float:right; display:none" id="styleLoadError">
			<b>Styles could not be found. Please ensure 'themes' folder exists in your documentation folder root.</b>
		</div>		
		<div style="float:right; display:none" id="styleChooser">
			<label for="style_select"> Select Style </label>
			<select onchange=handleStyleSelectChange(this) id="style_select">
				${themeString}
			</select>
		</div>	
	`;
	return injectHtml;
}


/**
 * @Description converts safe html entities &lt; &gt; &amp; in a string to < > & so they can be properly rendered in the browser.
 * @param string escapedHTML 
 * @Return string with characters converted to unescaped versions.
 */
function unescapeHTML(escapedHTML) {
    return escapedHTML.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}

/**
 * @Description Gets all files from a directory tree recursively.
 * @Param directory the root directory to look for files in
 * @Param files internal variable passed to each call of itself. Do not set, or set to empty array.
 * @Return an array of complete file paths for all files in the directory.
 */
function getFilesRecursively(directory, fileTypes, files) {

	logEvent("Getting files recursively with types...");
	logEvent(fileTypes);
    if (!files) files = [];
    fs.readdirSync(directory).forEach(File => {
        const absolute = path.join(directory, File);
		var filePathParts = File.split('.');
		var fileExtension = filePathParts[filePathParts.length-1];

		logEvent('Looking at file for listint: ' + File + ' Extension: '+ fileExtension);

        if (fs.statSync(absolute).isDirectory()) return getFilesRecursively(absolute, fileTypes, files);
        else if(!fileTypes || fileTypes.includes(fileExtension)){
			
            files.push(absolute);
        }
    });

	logEvent("Returning found files");
	logEvent(files);
    return files;
}

function runCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        logEvent(`Error running command: ${command} - ${stderr}`);
        return reject(error);
      }
      logEvent(`Command executed successfully: ${command}`);
      resolve(stdout);
    });
  });
}

module.exports = { processFiles };

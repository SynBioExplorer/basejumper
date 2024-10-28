const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const baseDir = path.join(__dirname); // This will set the base directory to where the Electron app is running
const opensslPath = path.join(__dirname, 'openssl');
const libtorchPath = path.join(__dirname, 'libtorch');



// Event listener for 'quast' dropdown change
document.getElementById('quast').addEventListener('change', function() {
    let referenceField = document.getElementById('referenceFile');
    let referenceLabel = document.querySelector('label[for="referenceFile"]');
    if (this.value === 'yes') {
        referenceField.style.display = 'block';
        referenceLabel.style.display = 'block';
    } else {
        referenceField.style.display = 'none';
        referenceLabel.style.display = 'none';
    }
});

// Function to toggle input/output fields based on basecalling choice
function toggleBasecallingFields() {
    let basecalling = document.getElementById('basecalling').value;
    let doradoInputDiv = document.getElementById('doradoInputDiv');
    let doradoOutputDiv = document.getElementById('doradoOutputDiv');
    let genericInputDiv = document.getElementById('genericInputDiv');
    let genericOutputDiv = document.getElementById('genericOutputDiv');
    let kitNameDiv = document.getElementById('kitNameDiv'); 

    if (basecalling === 'dorado') {
        doradoInputDiv.style.display = 'block';
        doradoOutputDiv.style.display = 'block';
        genericInputDiv.style.display = 'none';
        genericOutputDiv.style.display = 'none';
        kitNameDiv.style.display = 'block'; 

    } else {
        doradoInputDiv.style.display = 'none';
        doradoOutputDiv.style.display = 'none';
        genericInputDiv.style.display = 'block';
        genericOutputDiv.style.display = 'block';
        kitNameDiv.style.display = 'none';
    }
}

// Ensure the correct fields are displayed on page load
document.addEventListener('DOMContentLoaded', function() {
    toggleBasecallingFields(); // Trigger the field toggle when the page first loads
});

// Event listener for basecalling option change
document.getElementById('basecalling').addEventListener('change', toggleBasecallingFields);

document.getElementById('startButton').addEventListener('click', () => {
    const startButton = document.getElementById('startButton');
    const consoleOutput = document.getElementById('consoleOutput');
    
    // Disable the button and change its text to give feedback
    startButton.disabled = true;
    startButton.textContent = 'Processing...';
    
    // Clear previous output and show a loading message
    consoleOutput.textContent = 'Starting process... Please wait.';

    let basecalling = document.getElementById('basecalling').value;
    let quast = document.getElementById('quast').value;
    let numBarcodes = document.getElementById('numBarcodes').value;
    let inputDir, outputDir, command;

    if (basecalling === 'dorado') {
        inputDir = document.getElementById('doradoInputDir').value;
        outputDir = document.getElementById('doradoOutputDir').value;
        kitName = document.getElementById('kit-name').value;
    } else {
        inputDir = document.getElementById('genericInputDir').value;
        outputDir = document.getElementById('genericOutputDir').value;
        kitName = 'NA';
    }

    let referenceFile = quast === 'yes' ? document.getElementById('referenceFile').value : 'NA';
    command = `zsh ${baseDir}/basejumper.zsh ${basecalling} ${inputDir} ${outputDir} ${quast} ${referenceFile} ${numBarcodes} ${outputDir} ${kitName}`;

    console.log('Command to be executed:', command);

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Execution error: ${error}`);
            consoleOutput.textContent = `Error: ${error.message}`;
            startButton.disabled = false;
            startButton.textContent = 'Start';
            return;
        }
        if (stderr) {
            console.error(`stderr: ${stderr}`);
            consoleOutput.textContent = `Error: ${stderr}`;
            startButton.disabled = false;
            startButton.textContent = 'Start';
            return;
        }

        // Display the output from the process
        consoleOutput.textContent = stdout;

        // Re-enable the button and reset its text after the process completes
        startButton.disabled = false;
        startButton.textContent = 'Start';

        let assemblyStatsFilePath = `${outputDir}/assembly_statistics.txt`;
        console.log('Assembly statistics file path:', assemblyStatsFilePath);

        if (fs.existsSync(assemblyStatsFilePath)) {
            createAssemblyStatsTable(assemblyStatsFilePath);
        } else {
            console.error('assembly_statistics.txt file not found:', assemblyStatsFilePath);
            consoleOutput.textContent += '\nError: assembly_statistics.txt file not found.';
        }
    });
});

// Function to parse assembly statistics and return table rows
function parseAssemblyStats(data) {
    const lines = data.split('\n').slice(1);
    return lines.map(line => {
        const [barcode, status, totalLength, meanCoverage] = line.trim().split(/\s+/);
        return `<tr><td>${barcode}</td><td>${status}</td><td>${totalLength}</td><td>${meanCoverage}</td></tr>`;
    }).join('');
}
function createAssemblyStatsTable(filePath) {
    fs.readFile(filePath, 'utf8', (err, data) => {
        if (err) {
            console.error("Error reading the file:", err);
            return;
        }

        // Parse the data to create table rows
        const tableRows = parseAssemblyStats(data);

        // Create the table
        const table = document.createElement('table');
        table.innerHTML = `
            <tr>
                <th>Barcode</th>
                <th>Status</th>
                <th>Total Length</th>
                <th>Mean Coverage</th>
            </tr>
            ${tableRows}
        `;

        // Append the table to a container in your HTML
        const container = document.getElementById('results-container');
        container.appendChild(table);
    });
}

console.log('Script completed.');

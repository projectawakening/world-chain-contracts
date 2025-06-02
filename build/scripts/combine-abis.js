const fs = require('fs');
const path = require('path');

// List of relative paths to ABI files
const abiFiles = [
    'mud-contracts/core-v2/out/IWorld.sol/IWorld.abi.json',
    'mud-contracts/smart-object-framework-v2/out/SmartObjectFramework.sol/SmartObjectFramework.abi.json',
    'mud-contracts/smart-object-framework-v2/out/IWorld.sol/IWorld.abi.json',
    'mud-contracts/world-v2/out/world/IWorld.sol/IWorld.abi.json',
];

// Function to create a unique key for an ABI item
function createUniqueKey(item) {
    if (!item.name) return null;

    const inputTypes = item.inputs ? item.inputs.map(input => input.type + input.name).join(',') : '';
    return `${item.type}${item.name}${inputTypes}`;
}

// Array to store all ABI items
const combinedABI = [];
const uniqueItems = new Map();

abiFiles.forEach((relativePath) => {
    const filePath = path.join(__dirname, '..', '..', relativePath);
    try {
        const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        const contractName = path.basename(path.dirname(filePath));

        // The content is already an ABI array
        if (Array.isArray(content)) {
            // Process each item and add to uniqueItems if not duplicate
            content.forEach(item => {
                const key = createUniqueKey(item);
                if (key && !uniqueItems.has(key)) {
                    uniqueItems.set(key, item);
                }
            });
            console.log(`Processed ${content.length} items from ${contractName}`);
        } else {
            console.warn(`Warning: ${filePath} does not contain a valid ABI array`);
        }
    } catch (e) {
        console.warn(`Failed to parse ${filePath}: ${e.message}`);
    }
});

// Convert Map values to array
const uniqueABI = Array.from(uniqueItems.values());

// Create artifacts directory if it doesn't exist
const artifactsDir = path.join(__dirname, '..', 'artifacts');
if (!fs.existsSync(artifactsDir)) {
    fs.mkdirSync(artifactsDir, { recursive: true });
}

// Write original combined ABI
const outputPath = path.join(artifactsDir, 'IWorld-v2.abi.json');
fs.writeFileSync(outputPath, JSON.stringify(uniqueABI, null, 2));
console.log(`\nCombined ${uniqueABI.length} unique ABI items into ${outputPath}`);

// Create meta-transaction compatible ABI version
const metaTxABI = uniqueABI.map(item => {
    if (item.name) {
        // Remove both prefixes if they exist
        let metaTxName = item.name.replace(/^evefrontier__/, '');
        metaTxName = metaTxName.replace(/^sofaccess__/, '');
        return { ...item, name: metaTxName };
    }
    return item;
});

// Write meta-transaction ABI
const metaTxOutputPath = path.join(artifactsDir, 'ERC2771IWorld-v2.abi.json');
fs.writeFileSync(metaTxOutputPath, JSON.stringify(metaTxABI, null, 2));
console.log(`Created meta-transaction compatible ABI in ${metaTxOutputPath}`);

// Create ABI with only error functions
const errorsOnlyABI = metaTxABI.filter(item => item.type === 'error');
const errorsOnlyOutputPath = path.join(artifactsDir, 'IWorld-v2-errors.abi.json');
fs.writeFileSync(errorsOnlyOutputPath, JSON.stringify(errorsOnlyABI, null, 2));
console.log(`Created ABI with only error functions in ${errorsOnlyOutputPath}`);
console.log(`Kept ${errorsOnlyABI.length} error functions`); 

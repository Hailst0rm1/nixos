/**
 * Generate an Excalidraw-style visual using Nano Banana (via kie.ai)
 *
 * Usage:
 *   node generate-visual.js "<prompt>" <output-file.png> [aspect-ratio] [--input <image> ...]
 *
 * Aspect ratios: 16:9 (default), 1:1, 4:5
 * --input: one or more reference images (local paths or URLs, up to 8)
 * Requires KIE_AI_API_KEY as environment variable
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const SCRIPT_DIR = __dirname;

const API_KEY = process.env.KIE_AI_API_KEY;
if (!API_KEY) {
  console.error('Error: KIE_AI_API_KEY not set. Add it to .env file.');
  process.exit(1);
}

// Parse arguments
const args = process.argv.slice(2);
const PROMPT = args[0];
const OUTPUT_FILE = args[1];

if (!PROMPT || !OUTPUT_FILE) {
  console.error('Usage: node generate-visual.js "<prompt>" <output-file.png> [aspect-ratio] [--input <image> ...]');
  process.exit(1);
}

// Parse aspect ratio and --input flag
let ASPECT_RATIO = '16:9';
const inputImages = [];

for (let i = 2; i < args.length; i++) {
  if (args[i] === '--input' && args[i + 1]) {
    i++;
    while (i < args.length && !args[i].startsWith('--')) {
      inputImages.push(args[i]);
      i++;
    }
    i--;
  } else if (!args[i].startsWith('--')) {
    ASPECT_RATIO = args[i];
  }
}

const VALID_RATIOS = ['16:9', '1:1', '4:5'];
if (!VALID_RATIOS.includes(ASPECT_RATIO)) {
  console.error(`Error: Invalid aspect ratio "${ASPECT_RATIO}". Use: ${VALID_RATIOS.join(', ')}`);
  process.exit(1);
}

if (inputImages.length > 8) {
  console.error('Error: Maximum 8 input images allowed.');
  process.exit(1);
}

function httpsRequest(url, options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        if (options.binary) {
          resolve(buffer);
        } else {
          resolve(buffer.toString('utf-8'));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function fileToBase64(filePath) {
  const absolutePath = path.resolve(filePath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Input image not found: ${absolutePath}`);
  }
  return fs.readFileSync(absolutePath).toString('base64');
}

async function uploadFileToKie(filePath) {
  const absolutePath = path.resolve(filePath);
  const ext = path.extname(absolutePath).toLowerCase();
  const mimeMap = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
  const mime = mimeMap[ext] || 'image/png';
  const base64 = fileToBase64(absolutePath);
  const dataUri = `data:${mime};base64,${base64}`;

  const fileName = path.basename(filePath);
  console.log(`  Uploading ${fileName} to kie.ai...`);

  const uploadBody = JSON.stringify({
    base64Data: dataUri,
    uploadPath: 'excalidraw-visuals',
    fileName: fileName,
  });

  const response = await httpsRequest(
    'https://kieai.redpandaai.co/api/file-base64-upload',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
      },
    },
    uploadBody
  );

  const data = JSON.parse(response);
  const url = data?.data?.downloadUrl || data?.data?.fileUrl || data?.data?.url || data?.url;

  if (url) {
    console.log(`  Uploaded: ${fileName} -> ${url.substring(0, 80)}...`);
    return url;
  }

  throw new Error(`Upload failed for ${filePath}. Response: ${response}`);
}

async function prepareImageInputs(images) {
  const results = [];
  for (const img of images) {
    if (img.startsWith('http://') || img.startsWith('https://')) {
      results.push(img);
    } else {
      const url = await uploadFileToKie(img);
      results.push(url);
    }
  }
  return results;
}

function downloadImage(url) {
  const client = url.startsWith('https') ? https : http;
  return new Promise((resolve, reject) => {
    client.get(url, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        downloadImage(res.headers.location).then(resolve).catch(reject);
        return;
      }
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

async function main() {
  const mode = inputImages.length > 0 ? 'image-to-image' : 'text-to-image';
  console.log(`Generating Excalidraw visual (${mode}, ${ASPECT_RATIO})...`);
  console.log(`Prompt length: ${PROMPT.length} chars`);
  if (inputImages.length > 0) {
    console.log(`Reference images: ${inputImages.length}`);
  }

  const input = {
    prompt: PROMPT,
    output_format: 'png',
    image_size: ASPECT_RATIO,
  };

  // Add image inputs if provided (upload local files to kie.ai first)
  if (inputImages.length > 0) {
    console.log('Uploading reference images...');
    const prepared = await prepareImageInputs(inputImages);
    input.image_input = prepared;
  }

  const createBody = JSON.stringify({
    model: 'google/nano-banana',
    input: input,
  });

  const createResponse = await httpsRequest(
    'https://api.kie.ai/api/v1/jobs/createTask',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
      },
    },
    createBody
  );

  const createData = JSON.parse(createResponse);
  const taskId = createData?.data?.taskId;

  if (!taskId) {
    console.error('Error: Failed to create task. Response:');
    console.error(createResponse);
    process.exit(1);
  }

  console.log(`Task created: ${taskId}`);
  console.log('Polling for result...');

  // Poll until complete (max 120 seconds)
  for (let i = 1; i <= 40; i++) {
    await sleep(3000);

    const pollResponse = await httpsRequest(
      `https://api.kie.ai/api/v1/jobs/recordInfo?taskId=${taskId}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${API_KEY}`,
        },
      }
    );

    const pollData = JSON.parse(pollResponse);
    const state = pollData?.data?.state;

    if (state === 'success') {
      const resultJson = JSON.parse(pollData.data.resultJson);
      const imageUrl = resultJson.resultUrls[0];

      if (imageUrl) {
        console.log('Downloading image...');

        const imageBuffer = await downloadImage(imageUrl);

        // Ensure output directory exists
        const outputDir = path.dirname(OUTPUT_FILE);
        if (!fs.existsSync(outputDir)) {
          fs.mkdirSync(outputDir, { recursive: true });
        }

        fs.writeFileSync(OUTPUT_FILE, imageBuffer);
        console.log(`Saved to: ${OUTPUT_FILE}`);
        process.exit(0);
      }
    } else if (state === 'fail') {
      console.error('Error: Image generation failed.');
      console.error(pollResponse);
      process.exit(1);
    }

    console.log(`  Status: ${state} (attempt ${i}/40)`);
  }

  console.error('Error: Timed out waiting for image generation.');
  process.exit(1);
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});

const Tesseract = require('tesseract.js');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const { debugLog } = require('../utils/logging');
const util = require('util');

const OUTPUT_DIR = 'extracted_text_boxes';

// Helper function to check if the pixel color matches the target color
function colorsMatch(pixel, targetColor, channels) {
  if (channels === 4) {
    return (
      pixel[0] === targetColor.r &&
      pixel[1] === targetColor.g &&
      pixel[2] === targetColor.b &&
      pixel[3] === 255
    );
  } else if (channels === 3) {
    return (
      pixel[0] === targetColor.r &&
      pixel[1] === targetColor.g &&
      pixel[2] === targetColor.b
    );
  }
  return false;
}

// Function to find bounding boxes that match the target color
async function getTextBoxBoundingBoxes(imageBuffer, width, height, channels, targetColor) {
  const boundingBoxes = [];
  const visited = new Array(width * height).fill(false);
  const getIndex = (x, y) => y * width + x;

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = getIndex(x, y);
      if (visited[idx]) continue;

      const pixelStart = idx * channels;
      const pixel = imageBuffer.slice(pixelStart, pixelStart + channels);
      if (colorsMatch(pixel, targetColor, channels)) {
        const queue = [];
        queue.push({ x, y });
        visited[idx] = true;

        let minX = x,
          maxX = x;
        let minY = y,
          maxY = y;

        while (queue.length > 0) {
          const { x: currentX, y: currentY } = queue.shift();

          const neighbors = [
            { x: currentX + 1, y: currentY },
            { x: currentX - 1, y: currentY },
            { x: currentX, y: currentY + 1 },
            { x: currentX, y: currentY - 1 },
          ];

          for (const neighbor of neighbors) {
            if (
              neighbor.x >= 0 &&
              neighbor.x < width &&
              neighbor.y >= 0 &&
              neighbor.y < height
            ) {
              const neighborIdx = getIndex(neighbor.x, neighbor.y);
              if (!visited[neighborIdx]) {
                const neighborPixelStart = neighborIdx * channels;
                const neighborPixel = imageBuffer.slice(
                  neighborPixelStart,
                  neighborPixelStart + channels
                );
                if (colorsMatch(neighborPixel, targetColor, channels)) {
                  queue.push({ x: neighbor.x, y: neighbor.y });
                  visited[neighborIdx] = true;

                  minX = Math.min(minX, neighbor.x);
                  maxX = Math.max(maxX, neighbor.x);
                  minY = Math.min(minY, neighbor.y);
                  maxY = Math.max(maxY, neighbor.y);
                }
              }
            }
          }
        }

        const padding = -1;
        const removePointingCaret = 6;
        boundingBoxes.push({
          left: Math.max(0, Math.min(minX - padding, width - 1)),
          top: Math.max(0, Math.min(minY - padding, height - 1)),
          width: Math.max(
            1,
            Math.min(maxX - minX + 2 * padding, width - Math.max(0, minX - padding))
          ),
          height: Math.max(
            1,
            Math.min(maxY - minY + 2 * padding, height - Math.max(0, minY - padding))
          ) - removePointingCaret,
        });
      }
    }
  }

  return boundingBoxes;
}

// Function to extract boxes from image
async function extractTextBoxes(inputImagePath, targetColor) {
  const image = sharp(inputImagePath);
  const metadata = await image.metadata();
  const { width, height, channels } = metadata;

  if (channels !== 3 && channels !== 4) {
    throw new Error(`Unsupported number of channels: ${channels}. Only RGB and RGBA are supported.`);
  }

  const { data } = await image.raw().toBuffer({ resolveWithObject: true });
  const boundingBoxes = await getTextBoxBoundingBoxes(data, width, height, channels, targetColor);
  debugLog(`Found ${boundingBoxes.length} text box(es).`);

  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR);
  }

  const extractedImages = [];
  for (let i = 0; i < boundingBoxes.length; i++) {
    const image = sharp(inputImagePath);
    let box = boundingBoxes[i];

    // Skip small boxes, those are artifacts, or rediscoveries of the characters in the same box.
    if (box.width < 50 && box.height < 30) {
      continue;
    }

    const outputPath = path.join(OUTPUT_DIR, `text_box_${i + 1}.png`);
    await image.extract(box).ensureAlpha().png().toFile(outputPath);
    extractedImages.push(outputPath);
  }

  return extractedImages;
}

// Extract boxes with `targetColor` and perform OCR on those.
/**
 * Recognizes text from a screenshot image.
 *
 * @param {string} imagePath - The path to the screenshot image.
 * @param {object} targetColor - The target color to extract text boxes. Default is { r: 53, g: 57, b: 59 } and it represent the service labels in the Observability graph.
 * @param {string[]} expectedWords - An array of expected words to recognize.
 * @returns {Promise<string[]>} - A promise that resolves to an array of recognized texts.
 */
async function recognizeTextFromScreenshot(imagePath, expectedWords = [], glooUILayoutSelector = 'originalUISelectors') {
  var targetColor;
  if (glooUILayoutSelector === 'reactFlowUISelectors') {
    targetColor = { r: 255, g: 255, b: 255 };
  } else {
    // Original UI RGB values
    targetColor = { r: 53, g: 57, b: 59 };
  }
  console.log(`Using targetColor profile: ${util.inspect(targetColor, { depth: null })} for ${glooUILayoutSelector}.`);
  const whitelist = expectedWords.join('').replace(/\s+/g, '');
  const extractedImages = await extractTextBoxes(imagePath, targetColor);

  const recognizedTexts = [];
  for (const image of extractedImages) {
    const text = await Tesseract.recognize(image, 'eng', {
      tessedit_pageseg_mode: 11,
      tessedit_ocr_engine_mode: 1,
      tessedit_char_whitelist: whitelist,
    }).then(({ data: { text } }) => text);
    recognizedTexts.push(text);
  }

  return recognizedTexts;
}

module.exports = {
  recognizeTextFromScreenshot,
};

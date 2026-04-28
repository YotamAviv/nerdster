/**
 * fetchImages — callable Cloud Function handler
 *
 * Fetches high-quality images for a subject to enhance visual presentation.
 * This is dynamic and NOT part of the subject's identity.
 * Fail Fast: Requires a subject with a contentType.
 */

const { executeFetchImages } = require('./core_logic');

async function handleFetchImages(data, logger) {
  const maxImages = data.maxImages || 1;
  return await executeFetchImages(data.subject, logger, maxImages);
}

module.exports = { handleFetchImages };

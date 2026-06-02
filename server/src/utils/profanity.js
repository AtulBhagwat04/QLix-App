const badWords = [
  'fuck', 'shit', 'asshole', 'bitch', 'crap', 'cunt', 'bastard', 'dick', 'pussy', 'slut'
];

const badWordsRegex = new RegExp(`\\b(${badWords.join('|')})\\b`, 'gi');

/**
 * Checks if a string contains profanity.
 * @param {string} text 
 * @returns {boolean}
 */
export const containsProfanity = (text) => {
  return badWordsRegex.test(text);
};

/**
 * Replaces bad words with asterisks.
 * @param {string} text 
 * @returns {string}
 */
export const filterProfanity = (text) => {
  return text.replace(badWordsRegex, (match) => '*'.repeat(match.length));
};

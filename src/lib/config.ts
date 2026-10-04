// Edit these three values, then commit and push so Vercel redeploys.
// They are shown to every visitor, so only put public details here.
export const EASYPAISA_NUMBER = '0313-7884970';        // number customers send payment to
export const EASYPAISA_ACCOUNT_NAME = ''; // optional: name on that Easypaisa account (leave '' to hide)
export const WHATSAPP_NUMBER = '923034620594';         // country code first, digits only (no + or spaces)

// Features switch on automatically once real numbers are filled in.
export const easypaisaReady = !/X/i.test(EASYPAISA_NUMBER) && EASYPAISA_NUMBER.replace(/\D/g, '').length >= 10;
export const whatsappReady = /^\d{10,15}$/.test(WHATSAPP_NUMBER);
export const whatsappLink = (text?: string) => `https://wa.me/${WHATSAPP_NUMBER}${text ? `?text=${encodeURIComponent(text)}` : ''}`;

// Home page headline (one string per line) and the sentence under it. Edit freely.
export const HERO_TITLE = ['Everyday wear', 'and PAF collectibles.'];
export const HERO_TEXT = 'Caps, apparel and aircraft models. Pay cash on delivery or by Easypaisa, and we deliver across Pakistan.';

export const formatPhone = (digits: string) => (/^92\d{10}$/.test(digits) ? `+92 ${digits.slice(2, 5)} ${digits.slice(5)}` : digits);

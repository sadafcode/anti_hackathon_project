export interface NadraResult {
  verified: boolean;
  reason: 'format_invalid' | 'mock_verified' | 'mock_rejected' | 'no_nic';
  name?: string;
}

// Pakistani CNIC: 13 digits — DDDDD-SSSSSSS-G
// First 5 = district code, next 7 = sequence, last 1 = gender (odd=male, even=female)
function validateNicFormat(nic: string): boolean {
  if (!/^\d{13}$/.test(nic)) return false;
  if (parseInt(nic.substring(0, 5)) < 10101) return false;
  if (nic.substring(5, 12) === '0000000') return false;
  return true;
}

// Demo providers — only these NICs get blue tick in hackathon demo
const DEMO_VERIFIED: Record<string, string> = {
  '4210112345671': 'Ali Hassan',
  '3520198765432': 'Tariq Mehmood',
  '6110187654321': 'Bilal Ahmed',
  '3520112233445': 'Usman Ali',
  '6110198877665': 'Sana Malik',
  '4210187654322': 'Aslam Khan',
};

export async function verifyNic(nic: string): Promise<NadraResult> {
  if (!nic) return { verified: false, reason: 'no_nic' };

  const clean = nic.replace(/[-\s]/g, '');

  if (!validateNicFormat(clean)) {
    return { verified: false, reason: 'format_invalid' };
  }

  const name = DEMO_VERIFIED[clean];
  if (name) {
    return { verified: true, reason: 'mock_verified', name };
  }

  return { verified: false, reason: 'mock_rejected' };
}

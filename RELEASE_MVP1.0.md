# 🇳🇴 SwapNorge — Release Snapshot: MVP 1.0 (Updated)

- **Release Tag**: `MVP1.0`
- **Archive File**: `MVP1.0-backup.tar.gz` (Clean source archive without node_modules/.next)
- **Snapshot Date**: September 2026
- **Status**: Production Verified & Compiled Cleanly (Next.js 15 App Router)

---

## 🎯 Scope of MVP 1.0 (Baseline Prior to Intuition Web3 Integration)

1. **Local Norwegian Neighborhood Swap & Share Hub**:
   - P2P and C2C second-hand item giveaway, borrowing, and swapping.
   - Dual-language support (Norwegian Bokmål & English) with URL persistence.
2. **Offline & Real-World Safety Verification**:
   - 4-digit dynamic passcode with live reverse-geocoded GPS radius check.
   - Real-time scheduled handover times and interactive appointment management.
3. **Legal & GDPR Compliance Framework**:
   - Datatilsynet-compliant Cookie consent and data anonymization controls.
   - Forbrukertilsynet C2C notice and non-commercial disclaimer.
4. **Community Feedback Engine**:
   - Floating beta feedback widget with local history and automated ticket ID generation.
5. **Resilient Authentication & OTP Password Recovery**:
   - Supabase Auth integration with intelligent fallback and offline session recovery.
   - Two-step OTP verification flow for password reset, with token extraction and network error resilience.
   - Instant local session activation preventing 503 network lockouts.

---

## 🔄 How to Restore to this Snapshot
- **Via Git Tag**: `git checkout MVP1.0`
- **Via Backup Archive**: `tar -xzf MVP1.0-backup.tar.gz`

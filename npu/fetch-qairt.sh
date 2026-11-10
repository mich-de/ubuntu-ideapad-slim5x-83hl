#!/bin/bash
# Scarica da Qualcomm (URL pubblico, senza login) SOLO i file QAIRT necessari (~150 MB su 1.5 GB) via HTTP Range.
# Licenza proprietaria Qualcomm (qairt/<ver>/LICENSE.pdf). Uso: fetch-qairt.sh [versione]
set -euo pipefail
ROOT=${ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
V=${1:-2.47.0.260601}; N=$ROOT/npu; E=${V//./\\.}
python3 -I $N/tools/rzip.py "https://softwarecenter.qualcomm.com/api/download/software/sdks/Qualcomm_AI_Runtime_Community/All/$V/v$V.zip" extract \
 "^qairt/$E/(LICENSE\\.pdf|NOTICE\\.txt|sdk\\.yaml|bin/aarch64-oe-linux-gcc11\\.2/(qnn-net-run|qnn-platform-validator|qnn-context-binary-generator)|lib/aarch64-oe-linux-gcc11\\.2/(libQnnHtp\\.so|libQnnHtpV73Stub\\.so|libQnnHtpV73CalculatorStub\\.so|libQnnSystem\\.so|libQnnHtpPrepare\\.so|libQnnHtpNetRunExtensions\\.so|libQnnCpu\\.so|libPlatformValidatorShared\\.so|libcalculator\\.so)|lib/hexagon-v73/unsigned/(libQnnHtpV73Skel\\.so|libCalculator_skel\\.so|libqnnhtpv73\\.cat)|examples/QNN/converter/models/.*|include/QNN/.*|share/QNN/converter/.*)\$" $N/qairt

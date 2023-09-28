#!/bin/bash
set -euo pipefail

call_short_tandem_repeats () {
    local args=()
    args+=("--loci" "!{paramLoci}")
    args+=("--sample" "!{sampleId}")
    args+=("--vcf" "straglr.vcf")
    if [ -z "!{sampleSex}" ]; then
        args+=("--sex" "!{sampleSex}")
    fi
    args+=("--min_support" "!{paramMinSupport}")
    args+=("--min_cluster_size" "!{paramMinClusterSize}")
    args+=("!{cram}")
    args+=("!{paramReference}")

    ${CMD_STRAGLR} "${args[@]}"
}

index () {
  # workaround for https://github.com/molgenis/vip/issues/471
  ${CMD_BCFTOOLS} reheader --fai "!{paramReferenceFai}" --temp-prefix . --threads "!{task.cpus}" "straglr.vcf" | ${CMD_BCFTOOLS} sort --temp-dir . --max-mem "!{task.memory.toGiga() - 1}" --output-type z --output "!{vcfOut}"

  ${CMD_BCFTOOLS} index --csi --output "!{vcfOutIndex}" --threads "!{task.cpus}" "!{vcfOut}"
  ${CMD_BCFTOOLS} index --stats "!{vcfOut}" > "!{vcfOutStats}"

  rm straglr.vcf
}

main() {
    call_short_tandem_repeats
    index
}

main "$@"
#!/bin/bash
set -euo pipefail

call_structural_variants () {
  local args=()
  args+=("--sample" "!{sampleId}")
  args+=("--genotype")

  if [[ "!{sequencingPlatform}" == "nanopore" ]]; then
    args+=("--max_cluster_bias_INS" "100")
    args+=("--diff_ratio_merging_INS" "0.3")
    args+=("--max_cluster_bias_DEL" "100")
    args+=("--diff_ratio_merging_DEL" "0.3")
  elif [[ "!{sequencingPlatform}" == "pacbio_hifi" ]]; then
    args+=("--max_cluster_bias_INS" "1000")
    args+=("--diff_ratio_merging_INS" "0.9")
    args+=("--max_cluster_bias_DEL" "1000")
    args+=("--diff_ratio_merging_DEL" "0.5")
  fi

  args+=("--threads" "!{task.cpus}")
  args+=("!{cram}")
  args+=("!{reference}")
  args+=("cutesv_output.vcf")
  args+=(".")

  ${CMD_CUTESV} "${args[@]}"
}

fixref () {
  # Workaround for https://github.com/tjiangHIT/cuteSV/issues/124
  while IFS=$'\t' read -r -a fields
  do
    if [[ "${fields[0]}" != \#* && "${fields[3]}" == "N" ]]; then
      ref=$(${CMD_SAMTOOLS} faidx "!{reference}" "${fields[0]}:${fields[1]}-${fields[1]}" | sed -n '2 p')
      fields[3]="${ref}"
      length="${#fields[4]}"
      #Fix breakend ALTS
      if [[ "${fields[4]}" == \]* && "${fields[4]}" == *N ]]; then
        fields[4]="${fields[4]:0:(length-1)}${ref}"
      elif [[ "${fields[4]}" == *\[ && "${fields[4]}" == N* ]]; then
        fields[4]="${ref}${fields[4]:1:length}"
      #Fix regular insertion ALT
      elif [[ "${fields[4]}" == N* && "${length}" -gt 1 ]]; then
        fields[4]="${ref}${fields[4]:1:length}"
      fi
    fi
    (IFS=$'\t'; echo "${fields[*]}") >> "fixed_ref_output.vcf"
  done < "cutesv_output.vcf"
}

postprocess () {
    # Workaround for https://github.com/tjiangHIT/cuteSV/issues/124
    cat "fixed_ref_output.vcf" | awk -v FS='\t' -v OFS='\t' '/^[^#]/{gsub(/[YSB]/, "C", $4) gsub(/[WMRDHV]/, "A", $4) gsub("K", "G", $4)} 1' | ${CMD_BCFTOOLS} view --output-type z --output "replaced_IUPAC_cuteSV.vcf.gz" --no-version --threads "!{task.cpus}"
    ${CMD_BCFTOOLS} index --csi --output "replaced_IUPAC_cuteSV.vcf.gz.csi" --threads "!{task.cpus}" "replaced_IUPAC_cuteSV.vcf.gz"
    ${CMD_BCFTOOLS} view --output-type z --output "!{vcfOut}" --no-version --threads "!{task.cpus}" "cutesv_output.vcf"
    ${CMD_BCFTOOLS} index --csi --output "!{vcfOutIndex}" --threads "!{task.cpus}" "!{vcfOut}"
    ${CMD_BCFTOOLS} index --stats "!{vcfOut}" > "!{vcfOutStats}"
    rm "replaced_IUPAC_cuteSV.vcf.gz.csi" "replaced_IUPAC_cuteSV.vcf.gz" "fixed_ref_output.vcf" "cutesv_output.vcf"
}

main() {
    call_structural_variants
    fixref
    postprocess
}

main "$@"
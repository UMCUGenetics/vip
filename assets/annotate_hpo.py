from pandas import read_csv
from pyhpo import Ontology
from pyhpo.set import HPOSet
from csv import QUOTE_NONNUMERIC

# TODO: change hardcoded filepath of input to variable.
df = read_csv(
    "/Users/ejong19/repos/vip-2/assets/test_data/list_pats_V2_13-03-2023.csv",
    delimiter=";", quotechar='"'
)

_ = Ontology()

unknown = {}
for i, row in df.iterrows():
    diagnoses = row["Diagnosis"].rstrip(";").split("; ")
    hpo_terms = ""
    for diagnosis in diagnoses:
        try:
            hpo_term = Ontology.get_hpo_object(diagnosis.strip(" "))
        except RuntimeError:
            hpo_term = f"Unknown HPO for '{diagnosis}'"
            if not unknown.get(diagnosis):
                unknown[diagnosis] = 0
            unknown[diagnosis] += 1
        hpo_terms = f"{hpo_terms}; {str(hpo_term)}".lstrip("; ")
    df.at[i,'hpo'] = hpo_terms

# TODO: change hardcoded filepath of output to variable.
df.to_csv("/Users/ejong19/repos/vip-2/assets/test_data/annotated_list_patients_06062024_full.csv", index=False, quoting=QUOTE_NONNUMERIC, sep=";")

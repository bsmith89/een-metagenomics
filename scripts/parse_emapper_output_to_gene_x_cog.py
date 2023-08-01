#!/usr/bin/env python3

import pandas as pd
import sys
import numpy as np

EGGNOG_COLUMNS = "query seed_ortholog evalue score eggNOG_OGs max_annot_lvl COG_category Description Preferred_name GOs EC KEGG_ko KEGG_Pathway KEGG_Module KEGG_Reaction KEGG_rclass BRITE KEGG_TC CAZy BiGG_Reaction PFAMs".split(
    " "
)

if __name__ == "__main__":
    eggnog = (
        pd.read_table(sys.argv[1], comment="#", names=EGGNOG_COLUMNS, index_col="query")
        .rename_axis(index="gene_id")
        .replace({"-": np.nan})
    )
    gene_x_cog = (
        eggnog.eggNOG_OGs.dropna()
        .str.split(",")
        .explode()
        .str.split("@")
        .str[0][lambda x: x.str.startswith("COG")]
        .rename("cog")
    )
    gene_x_cog.to_csv(sys.argv[2], sep="\t")
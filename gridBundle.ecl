IMPORT Std.System.Thorlib;

IMPORT ML_Core as MLC;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
numericfield := MLC.types.NumericField;
Probability := HPCC_Causality.Probability;

nNodes := Thorlib.nodes();
node := Thorlib.node();

grid := RECORD 
    UNSIGNED ID;
    SET OF REAL gridItem;
END;

EXPORT DATASET (grid) makeGrid (DATASET ds, STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts=20, REAL lim):= FUNCTION 

    // if v2 is null and v3 is null . dims :=1
    // if v2 is not null And v3 is null, dims := 2
    // if v2 is not null and v3 is not null, dims := 3
    
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    
    // if the dataset is not passed, then how to get the distribution of the variable?
    NomalizedDS := NORMALIZE(ds, 3, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := counter,
                                    SELF.Value := IF( counter = 1, v1, 
                                                    IF(counter = 2, v2, v3))));

    prob := Probability(NFds, [v1, v2, v3]);

    // and what is ps in the grid.py? ProbSpace has the attribute distr.
    testDists := DATASET([{1, DATASET([{v1}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{v2}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{v3}], ProbSpec), DATASET([], ProbSpec)}
        ], ProbQuery);

    resultDist := prob.Distr(testDists);

    // convert to numeric field, similar to what I did in housingMain.ecl

    distrs := 
    // after getting the distribution, how can I get the percentile.

    // minvars is 1 percentile of distribution of v1
    // maxvars is 100 percentile of distribution of v1

    grid makeItem(UNSIGNED c) := TRANSFORM
    END; 
    grid := DATASET(nItems, makeItem(counter), LOCAL);
    return grid;
END;
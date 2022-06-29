IMPORT Std.System.Thorlib;
IMPORT HPCC_Causality;

Probability := HPCC_Causality.Probability;




nNodes := Thorlib.nodes();
node := Thorlib.node();

grid := RECORD 
    UNSIGNED ID;
    SET OF REAL gridItem;
END;

EXPORT DATASET (grid) makeGrid (STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts=20, REAL lim):= FUNCTION 

    // if v2 is null and v3 is null . dims :=1
    // if v2 is not null And v3 is null, dims := 2
    // if v2 is not null and v3 is not null, dims := 3
    
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    
    // if the dataset is not passed, then how to get the distribution of the variable?
    // and what is ps in the grid.py? ProbSpace has the attribute distr.
    
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
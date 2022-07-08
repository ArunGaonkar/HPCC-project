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

EXPORT DATASET (grid) makeGrid (TYPEOF(Probability) prob, STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts=20, REAL lim):= FUNCTION 

    // what is the type of prob?

    // if v2 is null and v3 is null. dims :=1
    // if v2 is not null And v3 is null, dims := 2
    // if v2 is not null and v3 is not null, dims := 3
    
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    numTests := POWER(numPts, dims);
    
    // if the dataset is not passed, then how to get the distribution of the variable?
    // convert to numeric field and get the distribution
    // NomalizedDS := NORMALIZE(ds, 3, TRANSFORM (numericfield, SELF.wi := 1,
    //                                 SELF.number := counter,
    //                                 SELF.ID := counter,
    //                                 SELF.Value := IF( counter = 1, v1, 
    //                                                 IF(counter = 2, v2, v3))));

    // prob := Probability(NomalizedDS, [v1, v2, v3]);

    // and what is ps in the grid.py? ProbSpace has the attribute distr.
    testDists := DATASET([{1, DATASET([{v1}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{v2}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{v3}], ProbSpec), DATASET([], ProbSpec)}
        ], ProbQuery);
    
    testdist2 := testDists[1..dims];

    resultDist := prob.Distr(testDists);

    v1min := resultDist.distr[1].minval;
    v1max := resultDist.distr[1].maxval;
    v2min := resultDist.distr[2].minval;
    v2max := resultDist.distr[2].maxval;    
    v3min := resultDist.distr[3].minval; 
    v3max := resultDist.distr[3].maxval;


    findPoint(REAL minv, REAL maxv, UNSIGNED indx) := FUNCTION
        val := (maxv - minv) / numPts * indx + minv;
        return val;
    END

    // after getting the distribution, how can I get the percentile.

    // minvars is 1 percentile of distribution of v1
    // maxvars is 100 percentile of distribution of v1

    grid makeItem(UNSIGNED c) := TRANSFORM
        SELF.id := c;
        x := TRUNCATE((c-1) / numPts);
        y := (c-1) % numPts + 1;
        self.gridItem[findPoint(v1min, v1max, x),findPoint(v2min, v2max, y)];
    END; 

    grid := DATASET(numPts, makeItem(counter));
    return grid;
END;
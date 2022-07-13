IMPORT Std.System.Thorlib;
nNodes := Thorlib.nodes();
node := Thorlib.node();

IMPORT ML_Core as MLC;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
NumericField := MLC.types.NumericField;
Probability := HPCC_Causality.Probability;

grid := RECORD 
    UNSIGNED ID;
    SET OF REAL gridItem;
END;

EXPORT makeGrid(DATASET(NumericField) ds, STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts=20, REAL lim):= FUNCTION 

    // getting the dimension
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    numTests := POWER(numPts, dims);
    
    prob := Probability(ds, [v1, v2, v3]);

    testDists := DATASET([{1, DATASET([{v1}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{v2}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{v3}], ProbSpec), DATASET([], ProbSpec)}
        ], ProbQuery);
    
    testdist2 := testDists[1..dims];

    // getting the distributions
    resultDist := prob.Distr(testDist2);
    
    // calcularing the minimum and maximum values of the distribution
    v1min := resultDist[1].minval;
    v1max := resultDist[1].maxval;
    v2min := resultDist[2].minval;
    v2max := resultDist[2].maxval;    
    v3min := resultDist[3].minval; 
    v3max := resultDist[3].maxval;

    findPoint(REAL minv, REAL maxv, UNSIGNED indx) := FUNCTION
        val := (maxv - minv) / numPts * indx + minv;
        return val;
    END;

    grid makeItem(UNSIGNED c) := TRANSFORM
        SELF.ID := c;
        x := TRUNCATE((c-1)/numPts);
        y := (c-1) % numPts + 1;
        self.gridItem:= [findPoint(v1min, v1max, x), findPoint(v2min, v2max, y)];
    END; 

    grid := DATASET(numPts, makeItem(counter));
    return grid;
END;
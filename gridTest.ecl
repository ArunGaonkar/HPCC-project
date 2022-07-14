#OPTION('outputLimitMb','100');
IMPORT Python3 AS Python;

IMPORT ML_Core;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
numericfield := ML_Core.types.NumericField;
Probability := HPCC_Causality.Probability;
Encoder := ML_Core.Preprocessing.LabelEncoder;

// initial record layout
initLayout := RECORD 
    UNSIGNED INTEGER5 id;
    UTF8 url;
    STRING region;
    STRING region_url;
    INTEGER price;
    STRING types;
    INTEGER sqfeet;
    INTEGER beds;
    REAL baths;
    BOOLEAN cats_allowed;
    BOOLEAN dogs_allowed;
    BOOLEAN smoking_allowed;
    BOOLEAN wheelchair_access;
    BOOLEAN electric_vehicle_charge;
    BOOLEAN comes_furnished;
    STRING lanudry_options;
    STRING parking_options;
    UTF8 image_url;
    STRING description;
    UTF8 lat;
    UTF8 long;
    STRING2 state;
END;

// housingInitDS := DATASET('housing::housing.csv', initLayout, CSV(HEADING(1)));
housingInitDS := DATASET('~.::housing1.csv', initLayout, CSV(HEADING(1)));

  /**
    * filtering the dataset based on the following criteria:
    * price >= $500 and price <= $3000 
    * sqfeet >= 500 and sqfeet <= 3000
    * beds >= 1 and beds <= 4 
    * baths >= 1 and baths <= 4 
    */

isGoodPrice := (housingInitDS.price >= 500) AND (housingInitDS.price <= 5000);
isGoodSqFeet := (housingInitDS.sqfeet >= 500) AND (housingInitDS.sqfeet <= 3000);
isGoodBeds := (housingInitDS.beds >= 1) AND (housingInitDS.beds <= 4);
isGoodBaths := (housingInitDS.baths >= 1) AND (housingInitDS.baths <= 4);
isHouse := (housingInitDS.types = 'house');

// record layout for encoding the 'types' field
KeyLayout := RECORD
    SET OF STRING types;
END;

// encoding keys for the 'types' field
key := ROW({['apartment', 'duplex', 'house', 'condo', 'flat', 'townhouse', 'manufactured', 'loft', 'cottage/cabin', 'in-law', 'land', 'assisted living']}, KeyLayout);

// filtering the dataset based on the above criteria
ds1 := housingInitDS(isGoodPrice, isGoodSqFeet, isGoodBeds, isGoodBaths); 

// encoding the 'types' in the dataset
ds2 := Encoder.encode(ds1, key); 

// sorting the dataset
ds3 := sort(ds2, types, price, sqfeet, beds, baths); 

// id now starts from 1
ds := PROJECT(ds3, TRANSFORM ( RECORDOF (LEFT), SELF.ID := COUNTER, SELF := LEFT)); 

// OUTPUT(COUNT(ds), ALL, NAMED('HousingDatasetSize'));
// OUTPUT(ds[..10000], ALL, NAMED('HousingDataset'));

// Normalize the dataset to NumericField record type of the following reordering. 
NFds := NORMALIZE(ds, 3, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := LEFT.ID,
                                    SELF.Value := IF( counter = 1, LEFT.price, 
                                                    IF(counter = 2, LEFT.sqfeet, LEFT.baths))));

// OUTPUT(COUNT(NFds), ALL, NAMED('NormalizedDatasetSize'));
// OUTPUT(NFDS[..10000], ALL, NAMED('normalizedDS'));

v1 := 'price';
v2 := 'sqfeet';
v3 := 'baths';
// beds, baths, types are discrete variables.

grid := RECORD 
    UNSIGNED ID;
    SET OF REAL gridItem;
END;

makeGrid(DATASET(NumericField) ds, STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts=5, REAL lim = 1.0):= FUNCTION 

    // getting the dimension
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    
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

    // output the distribution resultdist
    // OUTPUT(resultDist, ALL, NAMED('Distribution'));

    findPoint(REAL minv, REAL maxv, REAL numPtsx, UNSIGNED indx) := FUNCTION
        val := ((maxv - minv)/(numPtsx)) * indx + minv;
        return val;
    END;

    numPtsv1 := numPts;
    numPtsv2 := numPts;
    numPtsv3 := numPts;
    
    numTests := numPtsv1 * numPtsv2 * numPtsv3;
    
    // have to incorporate for the case of 3 dimensions 
    grid makeItem(UNSIGNED c) := TRANSFORM
        SELF.ID := c;
        x := (c-1) DIV (numPtsv2 * numPtsv3);
        y := ((c-1) DIV numPtsv3) % numPtsv2;
        z := (c-1) % (numPtsv3);
        self.gridItem := [findPoint(v1min, v1max, numPtsv1, x), findPoint(v2min, v2max, numPtsv2, y), findPoint(v3min, v3max, numPtsv3, z)];
    END; 

    grid := DATASET(numTests, makeItem(counter));
    return grid;
END;

gridResult := makeGrid(NFds, v1, v2, v3);
OUTPUT(gridResult, ALL, NAMED('OutputGrid'));




























/* version 1.0 without considering the discrete variables

makeGrid(DATASET(NumericField) ds, STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER numPts1=20, UNSIGNED INTEGER numPts2=20, UNSIGNED INTEGER numPts3=20, REAL lim = 1.0):= FUNCTION 

    // getting the dimension
    dims := IF(v3 = '', IF(v2 = '', 1, 2), 3);
    
    // prob := IF(v3 = '', IF(v2 = '', Probability(ds, [v1]), Probability(ds, [v1, v2])), Probability(ds, [v1, v2, v3]));

    // numTests := POWER(numPts, dims);
    
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

    // output the distribution resultdist
    // OUTPUT(resultDist, ALL, NAMED('Distribution'));

    findPoint(REAL minv, REAL maxv, REAL numPtsx, UNSIGNED indx) := FUNCTION
        val := ((maxv - minv)/(numPtsx)) * indx + minv;
        return val;
    END;

    numPtsv1 := numPts1;
    numPtsv2 := 20;
    numPtsv3 := 30;
    
    numTests := numPtsv1 * numPtsv2 * numPtsv3;
    
    // have to incorporate for the case of 3 dimensions 
    grid makeItem(UNSIGNED c) := TRANSFORM
        SELF.ID := c;
        x := (c-1) DIV (numPtsv2 * numPtsv3);
        y := ((c-1) DIV numPtsv3) % numPtsv2;
        z := (c-1) % (numPtsv3);
        self.gridItem := [findPoint(v1min, v1max, numPtsv1, x), findPoint(v2min, v2max, numPtsv2, y), findPoint(v3min, v3max, numPtsv3, z)];
    END; 

    grid := DATASET(numTests, makeItem(counter));
    return grid;
END;

gridResult := makeGrid(NFds, v1, v2, v3);
OUTPUT(gridResult, ALL, NAMED('OutputGrid'));
*/
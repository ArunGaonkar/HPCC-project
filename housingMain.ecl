#OPTION('outputLimitMb','100');

IMPORT ML_Core as MLC;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
numericfield := MLC.types.NumericField;

initLayout := RECORD 
    UNSIGNED INTEGER5 id;
    UTF8 url;
    STRING region;
    STRING region_url;
    INTEGER price;
    STRING types;
    INTEGER sqfeet;
    INTEGER beds;
    INTEGER baths;
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

housingInitDS := DATASET('housing::housing.csv', initLayout, CSV(HEADING(1)));

ds := sort(housingInitDS(price >= 500 AND price <= 10000 AND sqfeet >= 300 AND sqfeet <= 10000) , types, price, sqfeet, beds, baths);
OUTPUT(ds[..10000], ALL, NAMED('HousingDS'));

// sort the dataset based on the ID
// apply dedup to remove duplicate items, returns a dataset of unique rows
// remove any rows with empty values/NA values

// 1. price
// 2. sqfeet
// 3. beds
// 4. baths
// 5. types -- it is string-- so convert it to numeric type


NFds := NORMALIZE(ds, 4, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := LEFT.ID,
                                    SELF.Value := IF( counter = 1, LEFT.price, 
                                                    IF(counter = 2, LEFT.sqfeet, 
                                                    IF(counter = 3, LEFT.beds, LEFT.baths)))));


OUTPUT(NFDS[..10000], ALL, NAMED('normalizedDS'));

PS := HPCC_Causality.Probability(NFds, ['price', 'sqfeet', 'beds', 'baths']);

// DATASET([{1, DATASET([{'X1'}], ProbSpec), DATASET([], ProbSpec)}, // exp=2.5
//                   {2, DATASET([{'Y1'}], ProbSpec), DATASET([], ProbSpec)}, // exp=5
//                   {3, DATASET([{'Y1'}], ProbSpec), DATASET([{'X1', [2.5,100]}], ProbSpec)},
//                   {4, DATASET([{'Y1'}], ProbSpec), DATASET([{'X1', [1]}], ProbSpec)} // exp=2
//                   //{5, DATASET([{'ROLL'}], ProbSpec), DATASET([{'D1', [1,4]}, {'D2', [6]}], ProbSpec)} // exp=8
        // ], ProbQuery);


// Expected value of price
ePrice := ps.e(DATASET([{1, DATASET([{'price'}],ProbSpec)}], ProbQuery));
OUTPUT(ePrice, NAMED('ExpectedPrice'));

//try out for ps.distr,  and multiple conditional dependencies

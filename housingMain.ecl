#OPTION('outputLimitMb','100');

IMPORT ML_Core as MLC;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
numericfield := MLC.types.NumericField;
Probability := HPCC_Causality.Probability;

// intial record layout
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

housingInitDS := DATASET('housing::housing.csv', initLayout, CSV(HEADING(1)));

// filtering the dataset based on the following criteria:
// 1. price >= $1000 and price <= $10000
// 2. sqfeet >= 300 and sqfeet <= 10000
// 3. beds >= 1 and beds <= 4
// 4. baths >= 1 and baths <= 4

ds1 := housingInitDS(price >= 500 AND price <= 10000 AND sqfeet >= 300 AND sqfeet <= 10000 AND beds <= 4 AND beds >= 1 AND baths <= 4 AND baths >= 1);
ds2 := ds1(types = 'house'); //size is (29650, 22)

ds := sort(ds2, types, price, sqfeet, beds, baths);

OUTPUT(ds[..10000], ALL, NAMED('HousingDS'));

NFds := NORMALIZE(ds, 4, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := LEFT.ID,
                                    SELF.Value := IF( counter = 1, LEFT.price, 
                                                    IF(counter = 2, LEFT.sqfeet, 
                                                    IF(counter = 3, LEFT.beds, LEFT.baths)))));
// counter 1,2,3,4 = price, sqfeet, beds, baths

OUTPUT(NFDS[..10000], ALL, NAMED('normalizedDS'));

prob := Probability(NFds, ['price', 'sqfeet', 'beds', 'baths']);

// Expected value tests
testExp := DATASET([{1, DATASET([{'price'}], ProbSpec), DATASET([], ProbSpec)}, // exp=1370.915
                        {2, DATASET([{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)}, // exp=1496.42
                        {3, DATASET([{'beds'}], ProbSpec), DATASET([], ProbSpec)}, // exp=2.935
                        {4, DATASET([{'baths'}], ProbSpec), DATASET([], ProbSpec)}, // exp=1.825

                        {5, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}, // exp=1019.92
                        {6, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [600, 900]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}, // exp=883.92
                        {7, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [900, 1200]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}, // exp=1060.67
                        {8, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [1200, 1500]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}, // exp=1362.92
                        
                        {9, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1]},{'baths',[1]}], ProbSpec)}, // exp=1016.79
                        {10, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [600, 900]}, {'beds', [1]},{'baths',[1]}], ProbSpec)}, // exp=1099.03
                        {11, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [900, 1200]}, {'beds', [1]},{'baths',[1]}], ProbSpec)} // exp=1143.44
], ProbQuery);

resultExp := prob.E(testExp);
OUTPUT(resultExp, ALL, NAMED('expectedValues'));

// probability of the apartment to be equal to 500 is 0.0018
test := DATASET([{1, DATASET([{'price', [500]}], ProbSpec), DATASET([], ProbSpec)}], ProbQuery);

// Probability Tests
testProb := DATASET([{1, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([], ProbSpec)},   // exp = 0.393
                    {2, DATASET([{'price', [1000, 1500]}], ProbSpec), DATASET([], ProbSpec)},   // exp = 0.266
                    {3, DATASET([{'price', [1500, 2000]}], ProbSpec), DATASET([], ProbSpec)},   // exp = 0.189
                    {4, DATASET([{'price', [500, 1700]}], ProbSpec), DATASET([], ProbSpec)},    // exp = 0.755
                    {5, DATASET([{'price', [3000, 10000]}], ProbSpec), DATASET([], ProbSpec)},  // exp = 0.042


                    {6, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1, 3]}], ProbSpec)}, // exp = 0.577
                    {7, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'baths', [1, 3]}], ProbSpec)}, // exp = 0.403

                    {8, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[1]}], ProbSpec)}, // exp = 0.552
                    {9, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [2]}, {'baths',[1]}], ProbSpec)}, // exp = 0.638
                    {10, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [2]}, {'baths',[2]}], ProbSpec)}, // exp = 0.517
                    {11, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)}, // exp = 0.250
                    {12, DATASET([{'price', [1000, 1500]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)}, // exp = 0.312
                    {13, DATASET([{'price', [1500, 2000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)} // exp = 0.406
        ], ProbQuery);

resultProb := prob.P(testProb);
OUTPUT(resultProb, ALL, NAMED('Probabilities'));

// Distribution Tests
testDists := DATASET([{1, DATASET([{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{'baths'}], ProbSpec), DATASET([], ProbSpec)}
        ], ProbQuery);

resultDist := prob.Distr(testDists);
OUTPUT(resultDist, ALL, NAMED('Distributions'));

// To do
// distribution on conditional dependencies
// independence test 
// dependence test

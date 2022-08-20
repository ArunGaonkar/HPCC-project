#OPTION('outputLimitMb','100');

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

// filtering the dataset based on the following criteria:
// 1. price >= $500 and price <= $3000
// 2. sqfeet >= 500 and sqfeet <= 3000
// 3. beds >= 1 and beds <= 4
// 4. baths >= 1 and baths <= 4

isGoodPrice := (housingInitDS.price >= 500) AND (housingInitDS.price <= 3000);
isGoodSqFeet := (housingInitDS.sqfeet >= 500) AND (housingInitDS.sqfeet <= 3000);
isGoodBeds := (housingInitDS.beds >= 1) AND (housingInitDS.beds <= 4);
isGoodBaths := (housingInitDS.baths >= 1) AND (housingInitDS.baths <= 4);
// isHouse := (housingInitDS.types = 'house');

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

// OUTPUT(COUNT(ds), ALL, NAMED('HousingDatasetsize'));
// OUTPUT(ds[..10000], ALL, NAMED('HousingDataSet'));

// Normalize the dataset to NumericField record type of the following reordering. 
// counter 1,2,3,4,5 = price, sqfeet, beds, baths. types
NFds := NORMALIZE(ds, 5, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := LEFT.ID,
                                    SELF.Value := IF( counter = 1, LEFT.price, 
                                                    IF(counter = 2, LEFT.sqfeet, 
                                                    IF(counter = 3, LEFT.beds, 
                                                    IF(counter = 4, LEFT.baths, LEFT.types))))));

// OUTPUT(COUNT(NFds), ALL, NAMED('normalizedDSsize'));
// OUTPUT(NFDS[..10000], ALL, NAMED('normalizedDS'));

// Probability model for the dataset
prob := Probability(NFds, ['price', 'sqfeet', 'beds', 'baths', 'types']);

// Expected value tests
testExp := DATASET([{1, DATASET([{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)},
                        {6, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [600, 900]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)},
                        {7, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [900, 1200]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)},
                        {8, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [1200, 1500]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)},
                        {9, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1]},{'baths',[1]}], ProbSpec)},
                        {10, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [600, 900]}, {'beds', [1]},{'baths',[1]}], ProbSpec)},
                        {11, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [900, 1200]}, {'beds', [1]},{'baths',[1]}], ProbSpec)},
                        {12, DATASET([{'types'}], ProbSpec), DATASET([], ProbSpec)}
                ], ProbQuery);

// resultExp := prob.E(testExp);
// OUTPUT(resultExp, ALL, NAMED('expectedValues'));

// probability of the price to be equal to 500 is 0.0018
test := DATASET([{1, DATASET([{'price', [500]}], ProbSpec), DATASET([], ProbSpec)}], ProbQuery);

// Probability Tests
testProb := DATASET([{1, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([], ProbSpec)},
                    {2, DATASET([{'price', [1000, 1500]}], ProbSpec), DATASET([], ProbSpec)},
                    {3, DATASET([{'price', [1500, 2000]}], ProbSpec), DATASET([], ProbSpec)},
                    {4, DATASET([{'price', [500, 1700]}], ProbSpec), DATASET([], ProbSpec)},
                    {5, DATASET([{'price', [3000, 10000]}], ProbSpec), DATASET([], ProbSpec)},
                    {6, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1, 3]}], ProbSpec)},
                    {7, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'baths', [1, 3]}], ProbSpec)},
                    {8, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[1]}], ProbSpec)},
                    {9, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [2]}, {'baths',[1]}], ProbSpec)},
                    {10, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [2]}, {'baths',[2]}], ProbSpec)},
                    {11, DATASET([{'price', [500, 1000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)},
                    {12, DATASET([{'price', [1000, 1500]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)},
                    {13, DATASET([{'price', [1500, 2000]}], ProbSpec), DATASET([{'beds', [1]}, {'baths',[2]}], ProbSpec)}
                ], ProbQuery);

// resultProb := prob.P(testProb);
// OUTPUT(resultProb, ALL, NAMED('Probabilities'));

// Distribution Tests
testDists := DATASET([{1, DATASET([{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'types'}], ProbSpec), DATASET([], ProbSpec)},
                        {6, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}
                    ], ProbQuery);

// resultDist := prob.Distr(testDists);
// OUTPUT(resultDist, ALL, NAMED('Distributions'));

// Dependency Tests
testDep := DATASET([{1, DATASET([{'price'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{'price'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{'price'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{'price'},{'types'}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'sqfeet'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {6, DATASET([{'sqfeet'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {7, DATASET([{'sqfeet'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {8, DATASET([{'sqfeet'},{'types'}], ProbSpec), DATASET([], ProbSpec)},
                        {9, DATASET([{'beds'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {10, DATASET([{'beds'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {11, DATASET([{'beds'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {12, DATASET([{'beds'},{'types'}], ProbSpec), DATASET([], ProbSpec)},
                        {13, DATASET([{'baths'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {14, DATASET([{'baths'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {15, DATASET([{'baths'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {16, DATASET([{'baths'},{'types'}], ProbSpec), DATASET([], ProbSpec)},
                        {17, DATASET([{'types'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {18, DATASET([{'types'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {19, DATASET([{'types'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {20, DATASET([{'types'},{'baths'}], ProbSpec), DATASET([], ProbSpec)}
                    ], ProbQuery);

// Values less than .5 indicate probable independence.
// Values greater than .5 indicate probable dependence

// resultDep1 := prob.Dependence(testDep);
// OUTPUT(resultDep1, ALL, NAMED('DependencyTests1'));

// resultDep2 := prob.Dependence(testDep, dmethod := 'rcot');
// OUTPUT(resultDep2, ALL, NAMED('DependencyTests2'));

// Independence Tests
// Result of 1 indicates that the two targets are most likely independent. 
// 0 indicates probable dependence.

// resultsIndep1 := prob.isIndependent(testDep); 
// OUTPUT(resultsIndep1, ALL, NAMED('IndependenceTests1'));

// resultsIndep2 := prob.isIndependent(testDep, dmethod := 'rcot'); 
// OUTPUT(resultsIndep2, ALL, NAMED('IndependenceTests2'));

// Conditional dependency tests on 1 varible
testCondDep1var := DATASET([{1, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},
                            {2, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {3, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {4, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {5, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {6, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {7, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {8, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},
                            {9, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {10, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {11, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},
                            {12, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {13, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {14, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {15, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {16, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {17, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},
                            {18, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {19, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {20, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},
                            {21, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {22, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {23, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {24, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'types'}], ProbSpec)},
                            {25, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {26, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {27, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},
                            {28, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'price'}], ProbSpec)},
                            {29, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},
                            {30, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}
                        ], ProbQuery);

// resultCondDepprob1 := prob.Dependence(testCondDep1var, dmethod := 'prob');
// OUTPUT(resultCondDepprob1, ALL, NAMED('ConditionalDependencyTestsPROB'));

// resultsCondIndepprob1 := prob.isIndependent(testCondDep1var, dmethod := 'prob');
// OUTPUT(resultsCondIndepprob1, ALL, NAMED('ConditionalIndependenceTestsPROB'));

// resultCondDep2 := prob.Dependence(testCondDep1var, dmethod := 'rcot');
// OUTPUT(resultCondDep2, ALL, NAMED('ConditionalDependencyTestsRCOT'));

// resultsCondIndep2 := prob.isIndependent(testCondDep1var, dmethod := 'rcot');
// OUTPUT(resultsCondIndep2, ALL, NAMED('ConditionalIndependenceTestsRCOT'));

// Conditional dependency tests on 2 varible

// I had kept this to compare the runtime between a single query and all the queries.
// testCondDep2var := DATASET([{1, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}, {'baths'}], ProbSpec)}], ProbQuery);

testCondDep2var := DATASET([{1, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}, {'baths'}], ProbSpec)},
                            {2, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}, {'types'}], ProbSpec)},
                            {3, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'types'}, {'baths'}], ProbSpec)},
                            {4, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'}, {'baths'}], ProbSpec)},
                            {5, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'baths'}, {'types'}], ProbSpec)},
                            {6, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'types'}, {'sqfeet'}], ProbSpec)},
                            {7, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}, {'beds'}], ProbSpec)},
                            {8, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'beds'}, {'types'}], ProbSpec)},
                            {9, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'types'}, {'sqfeet'}], ProbSpec)},
                            {10, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}, {'baths'}], ProbSpec)},
                            {11, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'baths'}, {'beds'}], ProbSpec)},
                            {12, DATASET([{'price'}, {'types'}], ProbSpec), DATASET([{'beds'}, {'sqfeet'}], ProbSpec)},
                            {13, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'price'}, {'baths'}], ProbSpec)},
                            {14, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'baths'}, {'types'}], ProbSpec)},
                            {15, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'types'}, {'price'}], ProbSpec)},
                            {16, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'price'}, {'beds'}], ProbSpec)},
                            {17, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'beds'}, {'types'}], ProbSpec)},
                            {18, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'types'}, {'price'}], ProbSpec)},
                            {19, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'price'}, {'beds'}], ProbSpec)},
                            {20, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'beds'}, {'baths'}], ProbSpec)},
                            {21, DATASET([{'sqfeet'}, {'types'}], ProbSpec), DATASET([{'baths'}, {'price'}], ProbSpec)},
                            {22, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'price'}, {'sqfeet'}], ProbSpec)},
                            {23, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}, {'types'}], ProbSpec)},
                            {24, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'types'}, {'price'}], ProbSpec)},
                            {25, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'price'}, {'sqfeet'}], ProbSpec)},
                            {26, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}, {'baths'}], ProbSpec)},
                            {27, DATASET([{'beds'}, {'types'}], ProbSpec), DATASET([{'baths'}, {'price'}], ProbSpec)},
                            {28, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'price'}, {'sqfeet'}], ProbSpec)},
                            {29, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'sqfeet'}, {'beds'}], ProbSpec)},
                            {30, DATASET([{'baths'}, {'types'}], ProbSpec), DATASET([{'beds'}, {'price'}], ProbSpec)}
                        ], ProbQuery);

resultCondDep2Prob := prob.Dependence(testCondDep2var, dmethod := 'prob');
OUTPUT(resultCondDep2Prob, ALL, NAMED('ConditionalDependencyTests2Prob'));

resultsCondIndep2prob := prob.isIndependent(testCondDep2var, dmethod := 'prob');
OUTPUT(resultsCondIndep2Prob, ALL, NAMED('ConditionalIndependenceTests2Prob'));

resultCondDep2rcot := prob.Dependence(testCondDep2var, dmethod := 'rcot');
OUTPUT(resultCondDep2rcot, ALL, NAMED('ConditionalDependencyTests2rcot'));

resultsCondIndep2rcot := prob.isIndependent(testCondDep2var, dmethod := 'rcot');
OUTPUT(resultsCondIndep2rcot, ALL, NAMED('ConditionalIndependenceTests2rcot'));

// causal discovery
RVs := DATASET([{'price'}, 
                    {'sqfeet'}, 
                    {'beds'}, 
                    {'baths'},
                    {'types'}], Types.RV);

// mod := DATASET([{'housing', RVs}], Types.cModel);
// OUTPUT(mod, NAMED('Model'));

// cm := HPCC_Causality.Causality(mod, NFds);

// rept := cm.DiscoverModel();
// OUTPUT(rept, NAMED('DiscoveryReport'));
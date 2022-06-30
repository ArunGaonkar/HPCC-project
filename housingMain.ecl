#OPTION('outputLimitMb','100');

IMPORT ML_Core;
IMPORT HPCC_Causality;
IMPORT HPCC_Causality.Types;

ProbSpec := Types.ProbSpec;
ProbQuery := Types.ProbQuery;
numericfield := ML_Core.types.NumericField;
Probability := HPCC_Causality.Probability;
Encoder := ML_Core.Preprocessing.LabelEncoder;

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
isHouse := (housingInitDS.types = 'house');

KeyLayout := RECORD
    SET OF STRING types;
END;

key := ROW({['apartment', 'duplex', 'house', 'condo', 'flat', 'townhouse', 'manufactured', 'loft', 'cottage/cabin', 'in-law', 'land', 'assisted living']}, KeyLayout);

result1 := Encoder.encode(housingInitDS, key);
OUTPUT(result1[..10000],ALL, NAMED('typesEncoded'));

ds1 := housingInitDS(isGoodPrice, isGoodSqFeet, isGoodBeds, isGoodBaths);
ds2 := sort(ds1, types, price, sqfeet, beds, baths);

ds := PROJECT(ds2, TRANSFORM ( RECORDOF (LEFT), SELF.ID := COUNTER, SELF := LEFT));

OUTPUT(COUNT(ds), ALL, NAMED('DSsize'));
OUTPUT(ds[..10000], ALL, NAMED('HousingDS'));

NFds := NORMALIZE(ds, 4, TRANSFORM (numericfield, SELF.wi := 1,
                                    SELF.number := counter,
                                    SELF.ID := LEFT.ID,
                                    SELF.Value := IF( counter = 1, LEFT.price, 
                                                    IF(counter = 2, LEFT.sqfeet, 
                                                    IF(counter = 3, LEFT.beds, LEFT.baths)))));
// counter 1,2,3,4 = price, sqfeet, beds, baths

OUTPUT(COUNT(NFds), ALL, NAMED('size'));
OUTPUT(NFDS[..10000], ALL, NAMED('normalizedDS'));

prob := Probability(NFds, ['price', 'sqfeet', 'beds', 'baths']);

/*  Testing has been done for these blocks of code.

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
                        {4, DATASET([{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}
        ], ProbQuery);

resultDist := prob.Distr(testDists);
OUTPUT(resultDist, ALL, NAMED('Distributions'));

// Dependency Tests
// Values less than .5 indicate probable independence.
// Values greater than .5 indicate probable dependence

testDep := DATASET([{1, DATASET([{'price'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{'price'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{'price'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{'sqfeet'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'sqfeet'},{'beds'}], ProbSpec), DATASET([], ProbSpec)},
                        {6, DATASET([{'sqfeet'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {7, DATASET([{'beds'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {8, DATASET([{'beds'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {9, DATASET([{'beds'},{'baths'}], ProbSpec), DATASET([], ProbSpec)},
                        {10, DATASET([{'baths'},{'price'}], ProbSpec), DATASET([], ProbSpec)},
                        {11, DATASET([{'baths'},{'sqfeet'}], ProbSpec), DATASET([], ProbSpec)},
                        {12, DATASET([{'baths'},{'beds'}], ProbSpec), DATASET([], ProbSpec)}
                        ], ProbQuery);

resultDep := prob.Dependence(testDep);
OUTPUT(resultDep, ALL, NAMED('DependencyTests'));

// Independence Tests
// Result of 1 indicates that the two targets are most likely independent. 0 indicates probable dependence.
resultsIndep := prob.isIndependent(testDep); 
OUTPUT(resultsIndep, ALL, NAMED('IndependenceTests'));

// price and sqfeet are dependent with a confidence of 0.999
// price and beds are dependent with a confidence of 0.987
// price and baths are dependent with a confidence of 1
// beds and baths are dependent with a confidence of 0.999
// beds and sqfeet are dependent with a confidence of 1
// baths and sqfeet are dependent with a confidence of 0.999

// Conditional dependency tests
testCondDep := DATASET([{1, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},      // 0.866
                            {2, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)}, // 0.589
                            {3, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'beds'}], ProbSpec)},  // 0.888
                            {4, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},// 0 and independent
                            {5, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}, // 0.874
                            {6, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},// 0.948
                            
                            {7, DATASET([{'beds'}, {'price'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)},  // 0.054 but independent
                            {8, DATASET([{'beds'}, {'price'}], ProbSpec), DATASET([{'baths'}], ProbSpec)}, // 0.622
                            {9, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'price'}], ProbSpec)},  // 0.999
                            {10, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)}, // 0 and independent
                            {11, DATASET([{'beds'}, {'sqfeet'}], ProbSpec), DATASET([{'price'}], ProbSpec)}, // 0.683
                            {12, DATASET([{'beds'}, {'sqfeet'}], ProbSpec), DATASET([{'baths'}], ProbSpec)},// 0.735
                            
                            {13, DATASET([{'baths'}, {'price'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}, // 0.957
                            {14, DATASET([{'baths'}, {'price'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)}, // 0.632
                            {15, DATASET([{'baths'}, {'beds'}], ProbSpec), DATASET([{'price'}], ProbSpec)}, // 0.999
                            {16, DATASET([{'baths'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'}], ProbSpec)}, // 0.933
                            {17, DATASET([{'baths'}, {'sqfeet'}], ProbSpec), DATASET([{'price'}], ProbSpec)},// 0.959
                            {18, DATASET([{'baths'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}, // 0.986

                            {19, DATASET([{'sqfeet'}, {'price'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}, // 0.839
                            {20, DATASET([{'sqfeet'}, {'price'}], ProbSpec), DATASET([{'baths'}], ProbSpec)}, // 0.798
                            {21, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'price'}], ProbSpec)}, // 0.978
                            {22, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'baths'}], ProbSpec)}, // 0.904
                            {23, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'price'}], ProbSpec)}, // 0.999
                            {24, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'beds'}], ProbSpec)}   // 0.987
                            ], ProbQuery);

resultCondDep := prob.Dependence(testCondDep, dmethod := 'rcot');
OUTPUT(resultCondDep, ALL, NAMED('ConditionalDependencyTests'));

resultsCondIndep := prob.isIndependent(testCondDep, dmethod := 'rcot');
OUTPUT(resultsCondIndep, ALL, NAMED('ConditionalIndependenceTests'));

resultCondDepprob := prob.Dependence(testCondDep, dmethod := 'prob');
OUTPUT(resultCondDepprob, ALL, NAMED('ConditionalDependencyTestsprob'));

resultsCondIndepprob := prob.isIndependent(testCondDep, dmethod := 'prob');
OUTPUT(resultsCondIndepprob, ALL, NAMED('ConditionalIndependenceTestsprob'));

//ToDo:
// Conditional dependence tests, conditioned on 2 variable combinations
// find the mean, standard deviation of each variable 
// +- 2 standard deviations from the mean, in the interval of 15, 
// 1. find the expectation of price
// 2. find the expectation of price, conditioned on other variables

testCondDep2 := DATASET([{1, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'baths'},{'sqfeet'}], ProbSpec)},
                            {2, DATASET([{'price'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'},{'baths'}], ProbSpec)},
                            {3, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'beds'},{'sqfeet'}], ProbSpec)},
                            {4, DATASET([{'price'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'},{'beds'}], ProbSpec)},
                            {5, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'},{'baths'}], ProbSpec)},
                            {6, DATASET([{'price'}, {'sqfeet'}], ProbSpec), DATASET([{'baths'},{'beds'}], ProbSpec)},
                            
                            {7, DATASET([{'beds'}, {'price'}], ProbSpec), DATASET([{'sqfeet'},{'baths'}], ProbSpec)},
                            {8, DATASET([{'beds'}, {'price'}], ProbSpec), DATASET([{'baths'},{'sqfeet'}], ProbSpec)},
                            {9, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'price'},{'sqfeet'}], ProbSpec)},
                            {10, DATASET([{'beds'}, {'baths'}], ProbSpec), DATASET([{'sqfeet'},{'price'}], ProbSpec)},
                            {11, DATASET([{'beds'}, {'sqfeet'}], ProbSpec), DATASET([{'price'},{'baths'}], ProbSpec)},
                            {12, DATASET([{'beds'}, {'sqfeet'}], ProbSpec), DATASET([{'baths'},{'price'}], ProbSpec)},
                            
                            {13, DATASET([{'baths'}, {'price'}], ProbSpec), DATASET([{'beds'},{'sqfeet'}], ProbSpec)},
                            {14, DATASET([{'baths'}, {'price'}], ProbSpec), DATASET([{'sqfeet'},{'beds'}], ProbSpec)},
                            {15, DATASET([{'baths'}, {'beds'}], ProbSpec), DATASET([{'price'},{'sqfeet'}], ProbSpec)},
                            {16, DATASET([{'baths'}, {'beds'}], ProbSpec), DATASET([{'sqfeet'},{'price'}], ProbSpec)},
                            {17, DATASET([{'baths'}, {'sqfeet'}], ProbSpec), DATASET([{'price'},{'beds'}], ProbSpec)},
                            {18, DATASET([{'baths'}, {'sqfeet'}], ProbSpec), DATASET([{'beds'},{'price'}], ProbSpec)},
                            
                            {19, DATASET([{'sqfeet'}, {'price'}], ProbSpec), DATASET([{'beds'},{'baths'}], ProbSpec)},
                            {20, DATASET([{'sqfeet'}, {'price'}], ProbSpec), DATASET([{'baths'},{'beds'}], ProbSpec)},
                            {21, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'price'},{'baths'}], ProbSpec)},
                            {22, DATASET([{'sqfeet'}, {'beds'}], ProbSpec), DATASET([{'baths'},{'price'}], ProbSpec)},
                            {23, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'price'},{'beds'}], ProbSpec)},
                            {24, DATASET([{'sqfeet'}, {'baths'}], ProbSpec), DATASET([{'beds'},{'price'}], ProbSpec)}
                            ], ProbQuery);

resultCondDep2Prob := prob.Dependence(testCondDep2, dmethod := 'prob');
OUTPUT(resultCondDep2Prob, ALL, NAMED('ConditionalDependencyTests2Prob'));

resultsCondIndep2prob := prob.isIndependent(testCondDep2, dmethod := 'prob');
OUTPUT(resultsCondIndep2Prob, ALL, NAMED('ConditionalIndependenceTests2Prob'));

resultCondDep2rcot := prob.Dependence(testCondDep2, dmethod := 'rcot');
OUTPUT(resultCondDep2rcot, ALL, NAMED('ConditionalDependencyTests2rcot'));

resultsCondIndep2rcot := prob.isIndependent(testCondDep2, dmethod := 'rcot');
OUTPUT(resultsCondIndep2rcot, ALL, NAMED('ConditionalIndependenceTests2rcot'));
*/

/*
// causal discovery
RVs := DATASET([{'price'}, 
                    {'sqfeet'}, 
                    {'beds'}, 
                    {'baths'}], Types.RV);

mod := DATASET([{'housing', RVs}], Types.cModel);
OUTPUT(mod, NAMED('Model'));

cm := HPCC_Causality.Causality(mod, NFds);

rept := cm.DiscoverModel();
OUTPUT(rept, NAMED('DiscoveryReport'));
v1 := 'price';
v2 := 'sqfeet';
v3 := 'beds';
v4 := 'baths';

testDists := DATASET([{1, DATASET([{v1}], ProbSpec), DATASET([], ProbSpec)},
                        {2, DATASET([{v2}], ProbSpec), DATASET([], ProbSpec)},
                        {3, DATASET([{v3}], ProbSpec), DATASET([], ProbSpec)},
                        {4, DATASET([{v4}], ProbSpec), DATASET([], ProbSpec)},
                        {5, DATASET([{'price'}], ProbSpec), DATASET([{'sqfeet', [300, 600]}, {'beds', [1,3]},{'baths',[1,3]}], ProbSpec)}
        ], ProbQuery);

resultDist := prob.Distr(testDists);
OUTPUT(resultDist, ALL, NAMED('Distributions'));

OUTPUT(resultDist, ALL, NAMED('PriceDistribution'));
*/


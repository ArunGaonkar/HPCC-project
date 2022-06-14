housingLayout := RECORD 
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

housingDS := DATASET('housing::housing.csv', housingLayout, CSV(HEADING(1)));

OUTPUT(housingDS, NAMED('HousingDS'));

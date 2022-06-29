IMPORT Std.System.Thorlib;

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

    grid makeItem(UNSIGNED c) := TRANSFORM

    END; 
    grid := DATASET(nItems, makeItem(counter), LOCAL);
    return grid;
END;
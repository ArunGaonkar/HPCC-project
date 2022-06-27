IMPORT Std.System.Thorlib;

nNodes := Thorlib.nodes();
node := Thorlib.node();

grid := RECORD 
    UNSIGNED ID;
    SET OF REAL gridItem;
END;

EXPORT DATASET (grid) makeGrid (STRING v1, STRING v2='', STRING v3='', UNSIGNED INTEGER Incr=20):= FUNCTION 
    grid makeItem(UNSIGNED c) := TRANSFORM
    
    END; 
    grid := DATASET(nItems, makeItem(counter), LOCAL);
    return grid;
END;
function name = stateName(state)
%STATENAME Convert Audio_A state code to a readable label.

state = double(state);
switch state
    case 0
        name = "IDLE";
    case 1
        name = "PLAYING";
    case 2
        name = "COMPLETE";
    case 3
        name = "FAULT";
    case 4
        name = "ESTOP";
    otherwise
        name = "UNKNOWN";
end
end

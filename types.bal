// TradingView Webhook Alert Schema
public type TradingViewAlert record {|
    string symbol;
    string side; // Expected: "BUY" or "SELL"
    decimal price;
|};

// Gemini API Request Schemas
public type Part record {|
    string text;
|};

public type Content record {|
    Part[] parts;
|};

public type GeminiRequest record {|
    Content[] contents;
|};

// Gemini API Response Schemas
public type Candidate record {|
    Content content;
    string finishReason?;
|};

public type GeminiResponse record {|
    Candidate[] candidates;
|};
import ballerina/http;
import ballerina/io;
import ballerina/crypto;
import ballerina/time;

// Pulls the API key from Config.toml automatically
configurable string GEMINI_API_KEY = ?;
configurable string BINANCE_API_KEY = ?;
configurable string BINANCE_SECRET = ?;

// Initialize a global HTTP client pointing to Google's generative AI servers
final http:Client geminiClient = check new ("https://generativelanguage.googleapis.com");
final http:Client binanceClient = check new ("https://testnet.binance.vision");

function checkSentiment(string symbol, string side) returns string|error { 
    // 1. Construct the prompt using Ballerina's string template syntax
    string prompt = string `You are an expert crypto analyst. The technical indicator suggests a ${side} for ${symbol}. Based on the latest market sentiment, is this a good idea? Answer strictly with one word: BULLISH, BEARISH, or NEUTRAL.`;

    // 2. Build the request payload. 
    GeminiRequest requestPayload = {
        contents: [
            {
                parts: [
                    { text: prompt }
                ]
            }
        ]
    };

    // 3. Define the REST path with the API key
    string path = "/v1beta/models/gemini-3.6-flash:generateContent?key=" + GEMINI_API_KEY;

    // 4. Execute the HTTP POST request.
    // Magic happens here: ->post() automatically converts `requestPayload` to JSON, 
    // sends it, and parses the returned JSON directly into our `GeminiResponse` record.
    GeminiResponse response = check geminiClient->post(path, requestPayload); 

    // 5. Extract the AI's answer by drilling down into the record fields
    string sentiment = response.candidates[0].content.parts[0].text;
    
    // Clean up the response to remove any accidental line breaks or spaces
    return sentiment.trim();
}

function executeTrade(string symbol, string side) returns boolean|error {
    // 1. Get exact current time in milliseconds (Binance requires this to prevent replay attacks)
    [int, decimal] [seconds, fraction] = time:utcNow();
    int timestamp = seconds * 1000 + <int>(fraction * 1000);

    // 2. Define trade size (hardcoded for testnet, but dynamic in a real bot)
    string quantity = "0.01";

    // 3. Construct the query string. Binance expects data in the URL, not a JSON body.
    string queryString = string `symbol=${symbol}&side=${side}&type=MARKET&quantity=${quantity}&timestamp=${timestamp}`;

    // 4. Cryptographically sign the query string using your Secret Key
    byte[] messageBytes = queryString.toBytes();
    byte[] secretBytes = BINANCE_SECRET.toBytes();
    
    // Hash the message and convert the resulting bytes into a readable hex string
    byte[] signatureBytes = check crypto:hmacSha256(messageBytes, secretBytes);
    string signature = signatureBytes.toBase16();

    // 5. Append the signature to the end of the URL path
    string path = string `/api/v3/order?${queryString}&signature=${signature}`;

    // 6. Define the required Binance security header
    map<string> headers = {
        "X-MBX-APIKEY": BINANCE_API_KEY
    };

    // 7. Fire the request. The body is just an empty string "" because the data is in the URL.
    http:Response response = check binanceClient->post(path, "", headers = headers);

    // 8. Verify the result
    if response.statusCode == 200 {
        io:println("✅ Trade Executed Successfully for ", symbol);
        return true;
    } else {
        io:println("❌ Trade Failed: ", check response.getTextPayload());
        return false;
    }
}

service / on new http:Listener(8080) {

    resource function post alerts(@http:Payload TradingViewAlert alert) returns http:Accepted|error {
        
        io:println("----------------------------------------");
        io:println("🚨 Alert Received from TradingView!");
        io:println("Asset: ", alert.symbol, " | Action: ", alert.side);
        
        // 1. Call Gemini to get the current market sentiment
        string sentiment = check checkSentiment(alert.symbol, alert.side);
        io:println("🧠 AI Sentiment: ", sentiment);

        // 2. The Circuit Breaker Logic
        boolean shouldTrade = false;
        
        if alert.side == "BUY" && sentiment == "BULLISH" {
            shouldTrade = true;
        } else if alert.side == "SELL" && sentiment == "BEARISH" {
            shouldTrade = true;
        }

        // 3. Execute or Abort
        if shouldTrade {
            io:println("✅ Signals Align! Executing Trade...");
            // Call the Binance function
            boolean success = check executeTrade(alert.symbol, alert.side);
        } else {
            io:println("⛔ Trade Cancelled: Sentiment mismatch.");
        }
        
        io:println("----------------------------------------");
        
        // Acknowledge the webhook back to TradingView
        return http:ACCEPTED; 
    }
}


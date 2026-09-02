import ballerina/http;
import ballerina/io;

// Pulls the API key from Config.toml automatically
configurable string GEMINI_API_KEY = ?;

// Initialize a global HTTP client pointing to Google's generative AI servers
final http:Client geminiClient = check new ("https://generativelanguage.googleapis.com");
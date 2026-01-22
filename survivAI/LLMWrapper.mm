//
//  LLMWrapper.m
//  survivAI
//
//  Created by Muhammad Syafrizal on 03/05/25.
//

#import "LLMWrapper.h"
#import <llama/llama.h>

#import <regex>
#import <sstream>
#import <string>
#import <vector>

@implementation LLMWrapper {
    struct llama_model *model;
    struct llama_context *ctx;
    struct llama_sampler *sampler;
    NSString *systemPrompt;
    NSMutableArray<NSString *> *conversationHistory;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize conversation history
        conversationHistory = [[NSMutableArray alloc] init];

        // Define system prompt for the model to understand its role - direct,
        // no chit-chat
        systemPrompt =
            @"<|im_start|>system\n"
             "You are an emergency survival assistant.\n"
             "Always use all available conversation history to understand the "
             "user's current situation and risks.\n"
             "If the user asks about their \"situation\" or similar, analyze "
             "their previous messages and include all relevant details from "
             "history.\n"
             "Your response must be ONLY 5 bullet points.\n"
             "Each bullet must:\n"
             "• Start with '• '\n"
             "• Contain the ACTION in ALL CAPS\n"
             "• Follow with a hyphen and a short explanation\n"
             "No extra bullets. No extra sentences. No chit-chat.\n"
             "Example:\n"
             "• FIND SHELTER - Move to a safe, dry location\n"
             "• STAY WARM - Insulate with clothing or natural materials\n"
             "<|im_end|>";

        // Try to load model from Models directory first, then fall back to root
        NSString *path = [[NSBundle mainBundle]
            pathForResource:@"Models/Phi-3.5-mini-instruct_Uncensored-Q4_K_M"
                     ofType:@"gguf"];
        if (!path) {
            // Fallback: try root directory for backward compatibility
            path = [[NSBundle mainBundle]
                pathForResource:@"Phi-3.5-mini-instruct_Uncensored-Q4_K_M"
                         ofType:@"gguf"];
        }
        if (!path) {
            NSLog(@"Error: Model file 'Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf' not found in the bundle");
            NSLog(@"Please ensure the model file is added to the survivAI/Models/ directory");
            NSLog(@"Expected location: survivAI/Models/Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf");
            NSLog(@"Download from: https://huggingface.co/bartowski/Phi-3.5-mini-instruct_Uncensored-GGUF");
            // Don't fail initialization, just mark model as unavailable
            model = NULL;
            ctx = NULL;
            sampler = NULL;
            return self;
        }
        const char *modelPath = [path UTF8String];

        // Model parameters - optimized for iPhone 16 Pro
        struct llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers =
            40; // Use Metal for all possible layers on A18 Pro
        model = llama_model_load_from_file(modelPath, model_params);
        if (!model) {
            NSLog(@"Error: Failed to load model from path: %s", modelPath);
            NSLog(@"Please verify the model file is valid and compatible with llama.cpp");
            ctx = NULL;
            sampler = NULL;
            return self;
        }

        // Context parameters - optimized for iPhone 16 Pro (A18 Pro Bionic)
        struct llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 4096; // Context window for conversation history
        ctx_params.n_batch = 512; // Reasonable batch size that prevents assertion failures
        ctx_params.n_threads = 6; // A18 Pro has improved performance cores
        ctx_params.offload_kqv =
            true; // Offload KQV to save memory on mobile device

        ctx = llama_init_from_model(model, ctx_params);
        if (!ctx) {
            NSLog(@"Error: Failed to create context from model");
            NSLog(@"This may be due to insufficient memory or incompatible model parameters");
            llama_model_free(model);
            model = NULL;
            sampler = NULL;
            return self;
        }

        // Initialize sampler chain - optimized for deterministic, factual
        // bullet-list answers
        struct llama_sampler_chain_params sparams =
            llama_sampler_chain_default_params();
        sampler = llama_sampler_chain_init(sparams);

        // More deterministic settings for factual responses
        llama_sampler_chain_add(sampler,
                                llama_sampler_init_top_p(
                                    0.75, 1)); // Reduced for more deterministic
        llama_sampler_chain_add(
            sampler,
            llama_sampler_init_top_k(15)); // Reduced for more focused responses
        llama_sampler_chain_add(
            sampler, llama_sampler_init_temp(
                         0.4)); // Lower temperature for deterministic output

        // Mirostat v2 with more conservative settings for factual content
        llama_sampler_chain_add(sampler,
                                llama_sampler_init_mirostat_v2(2, 4.0, 0.08));

        NSLog(@"LLM initialized successfully with Phi 3 model and conversation "
              @"history");
    }
    return self;
}

- (int)countTokensInText:(NSString *)text {
    if (!model)
        return 0;

    const char *input = [text UTF8String];
    const struct llama_vocab *vocab = llama_model_get_vocab(model);

    // Get token count without actually tokenizing
    std::vector<llama_token> temp_tokens;
    temp_tokens.resize(8192); // Temporary large buffer

    int n_tokens =
        llama_tokenize(vocab, input, strlen(input), temp_tokens.data(),
                       temp_tokens.size(), true, false);
    return n_tokens > 0 ? n_tokens : 0;
}

- (NSString *)buildPromptWithHistory:(NSString *)newUserMessage {
    NSMutableString *fullPrompt =
        [NSMutableString stringWithString:systemPrompt];

    // Calculate token budget
    int maxContextTokens = llama_n_ctx(ctx);
    int reservedForGeneration = 200; // Ensure enough space for output
    int reservedForNewMessage = [self countTokensInText:newUserMessage] + 50;
    int systemPromptTokens = [self countTokensInText:systemPrompt];

    int availableForHistory = maxContextTokens - systemPromptTokens -
                              reservedForGeneration - reservedForNewMessage;

    // Build history from newest to oldest, respecting token limit
    NSMutableArray<NSString *> *includedHistory = [[NSMutableArray alloc] init];
    int currentHistoryTokens = 0;

    for (NSInteger i = conversationHistory.count - 1; i >= 0; i--) {
        NSString *turn = conversationHistory[i];
        int turnTokens = [self countTokensInText:turn];

        if (currentHistoryTokens + turnTokens <= availableForHistory) {
            [includedHistory insertObject:turn
                                  atIndex:0]; // keep chronological order
            currentHistoryTokens += turnTokens;
        } else {
            NSLog(@"Truncating conversation history at turn %ld to stay within "
                  @"token limit",
                  (long)i);
            break;
        }
    }

    // Add included history
    for (NSString *turn in includedHistory) {
        [fullPrompt appendString:turn];
    }

    // Detect summary-related questions
    NSString *lowerMsg = [newUserMessage lowercaseString];
    BOOL isSummaryQuestion =
        ([lowerMsg containsString:@"what is my situation"] ||
         [lowerMsg containsString:@"summarize my situation"] ||
         [lowerMsg containsString:@"what is happening"] ||
         [lowerMsg containsString:@"what happened to me"] ||
         [lowerMsg containsString:@"describe my situation"]);

    if (isSummaryQuestion) {
        [fullPrompt
            appendString:
                @"\nThe user is asking about their current survival situation. "
                 "Using only the information in the conversation history "
                 "above, "
                 "summarize their actual condition, location context, threats, "
                 "injuries, and urgent needs. "
                 "Do not give generic advice — describe exactly what has been "
                 "stated or implied. "
                 "Respond in exactly 5 bullet points as per the system "
                 "prompt.\n"];
    }

    // Add new user message
    [fullPrompt
        appendFormat:
            @"\n<|im_start|>user\n%@\n<|im_end|>\n<|im_start|>assistant\n",
            newUserMessage];

    NSLog(@"Built prompt with %lu history turns, total estimated tokens: %d",
          (unsigned long)includedHistory.count / 2,
          [self countTokensInText:fullPrompt]);

    return fullPrompt;
}

- (void)addToHistory:(NSString *)userMessage
            response:(NSString *)assistantResponse {
    // Count bullet points by splitting on "•" regardless of line breaks
    NSArray *bulletParts = [assistantResponse componentsSeparatedByString:@"•"];
    int validBullets = 0;
    
    for (NSString *part in bulletParts) {
        NSString *trimmedPart = [part stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // Skip empty parts (first part before first bullet is usually empty)
        if (trimmedPart.length == 0) continue;
        
        // Valid bullet must contain a hyphen (ACTION - description format)
        if ([trimmedPart containsString:@"-"]) {
            validBullets++;
        }
    }
    
    // Only add to history if we have proper bullet points
    if (validBullets >= 3) {
        // Add user turn
        NSString *userTurn =
            [NSString stringWithFormat:@"\n<|im_start|>user\n%@\n<|im_end|>",
                                       userMessage];
        [conversationHistory addObject:userTurn];

        // Add assistant turn
        NSString *assistantTurn = [NSString
            stringWithFormat:@"\n<|im_start|>assistant\n%@\n<|im_end|>",
                             assistantResponse];
        [conversationHistory addObject:assistantTurn];

        NSLog(@"Added valid conversation turn with %d bullet points. History "
              @"now has %lu entries",
              validBullets, (unsigned long)conversationHistory.count);
    } else {
        NSLog(
            @"Skipping malformed response with only %d valid bullet points: %@",
            validBullets, assistantResponse);
    }
}

- (NSString *)cleanGeneratedText:(NSString *)rawText {
    std::string text = [rawText UTF8String];

    // First, remove all chat markers and metadata
    std::regex chat_markers(
        "<\\|im_start\\|>.*?<\\|im_end\\|>|<\\|im_start\\|>|<\\|im_end\\|>");
    text = std::regex_replace(text, chat_markers, "");

    // Remove any chit-chat or extra intro text before the actual survival tips
    std::regex intro_pattern("^.*?(?:here are|EXACTLY|COMMANDS|STAY CALM)");
    text = std::regex_replace(text, intro_pattern, "");

    // Handle Phi-3 specific tokenization artifacts
    std::regex phi_g_macron("Ġ"); // G with macron above (common in tokenizers)
    text = std::regex_replace(text, phi_g_macron, " ");

    std::regex phi_c_dot("Ċ"); // C with dot above (often represents newlines)
    text = std::regex_replace(text, phi_c_dot, "\n");

    // Convert numbered list to clear bullet points
    std::regex numbered_list_pattern("([0-9]+)[.)]\\s*");
    text = std::regex_replace(text, numbered_list_pattern, "• ");

    // Handle any remaining Unicode special characters
    std::regex llama_underscore_pattern("▁");
    text = std::regex_replace(text, llama_underscore_pattern, " ");

    // Replace regular underscores with spaces
    std::regex underscore_pattern("_");
    text = std::regex_replace(text, underscore_pattern, " ");

    // Clean up colon formatting in bullet points for consistency
    std::regex colon_format("• ([^:\n]+):");
    text = std::regex_replace(text, colon_format, "• $1 -");

    // Handle control characters
    std::regex control_pattern("<0x[0-9A-F]+>");
    text = std::regex_replace(text, control_pattern, "");

    // Normalize newlines (convert multiple newlines to double newline)
    std::regex multi_newline("\\n{3,}");
    text = std::regex_replace(text, multi_newline, "\n\n");

    // Replace multiple spaces with a single space
    std::regex multi_space("\\s+");
    text = std::regex_replace(text, multi_space, " ");

    // Trim the leading/trailing whitespace
    std::regex leading_space("^\\s+");
    std::regex trailing_space("\\s+$");
    text = std::regex_replace(text, leading_space, "");
    text = std::regex_replace(text, trailing_space, "");

    // Fix any remaining bullet point issues
    std::regex fix_bullet_spacing("•\\s*");
    text = std::regex_replace(text, fix_bullet_spacing, "• ");

    return [NSString stringWithUTF8String:text.c_str()];
}

- (int)decodeTokensInChunks:(std::vector<llama_token> &)tokens 
                    startPos:(int)startPos 
                   batchSize:(int)batchSize 
                       seqId:(llama_seq_id)seqId {
    int totalTokens = (int)tokens.size();
    int currentPos = startPos;
    
    for (int i = 0; i < totalTokens; i += batchSize) {
        int chunkSize = std::min(batchSize, totalTokens - i);
        
        // Create batch for this chunk
        struct llama_batch batch = {0};
        batch.n_tokens = chunkSize;
        batch.token = tokens.data() + i;
        batch.pos = (llama_pos *)malloc(sizeof(llama_pos) * chunkSize);
        batch.n_seq_id = (int32_t *)malloc(sizeof(int32_t) * chunkSize);
        batch.seq_id = (llama_seq_id **)malloc(sizeof(llama_seq_id *) * chunkSize);
        batch.logits = (int8_t *)malloc(sizeof(int8_t) * chunkSize);

        if (!batch.pos || !batch.n_seq_id || !batch.seq_id || !batch.logits) {
            free(batch.pos);
            free(batch.n_seq_id);
            free(batch.seq_id);
            free(batch.logits);
            NSLog(@"Error: Memory allocation failed for chunk decode");
            return -1;
        }

        // Set up batch data
        for (int j = 0; j < chunkSize; j++) {
            batch.pos[j] = currentPos + j;
            batch.n_seq_id[j] = 1;
            batch.seq_id[j] = &seqId;
            // Only compute logits for the last token of the last chunk
            batch.logits[j] = (i + j == totalTokens - 1) ? 1 : 0;
        }

        // Decode this chunk
        int result = llama_decode(ctx, batch);

        // Free allocated memory
        free(batch.pos);
        free(batch.n_seq_id);
        free(batch.seq_id);
        free(batch.logits);

        if (result != 0) {
            NSLog(@"Error: Failed to decode chunk %d/%d, error code: %d", 
                  i / batchSize + 1, (totalTokens + batchSize - 1) / batchSize, result);
            return result;
        }
        
        currentPos += chunkSize;
        NSLog(@"Decoded chunk %d/%d (%d tokens)", 
              i / batchSize + 1, (totalTokens + batchSize - 1) / batchSize, chunkSize);
    }
    
    return 0;
}

- (NSString *)runPrompt:(NSString *)prompt {
    // Check if model and context are initialized
    if (!model || !ctx || !sampler) {
        NSLog(@"LLM not initialized - model:%p ctx:%p sampler:%p", model, ctx, sampler);
        return @"Error: The language model is not initialized. Please ensure Phi-3.5-mini-instruct_Uncensored-Q4_K_M.gguf is placed in the survivAI/Models/ directory and added to the Xcode project target.";
    }

    // Special case for test prompt
    if ([prompt isEqualToString:@"test"]) {
        return @"Ready to help in emergencies.";
    }

    // Check for "cold" or "freezing" keywords and use example response directly
    NSString *lowercasePrompt = [prompt lowercaseString];
    if ([lowercasePrompt containsString:@"cold"] ||
        [lowercasePrompt containsString:@"freezing"] ||
        [lowercasePrompt containsString:@"ice"] ||
        [lowercasePrompt containsString:@"snow"]) {
        NSString *coldResponse =
            @"• FIND SHELTER - Get out of wind and precipitation "
            @"immediately\n• STAY DRY - Remove wet clothing as it conducts "
            @"heat away from your body\n• LAYER CLOTHING - Trap air between "
            @"layers for better insulation\n• KEEP MOVING - Generate body heat "
            @"with light exercise, avoid sweating\n• STAY HYDRATED - Drink "
            @"warm liquids if available, avoid alcohol";
        [self addToHistory:prompt response:coldResponse];
        return coldResponse;
    }

    // Build prompt with conversation history
    NSString *fullPrompt = [self buildPromptWithHistory:prompt];

    NSLog(@"Processing prompt with history: %@", fullPrompt);
    const char *input = [fullPrompt UTF8String];

    @try {
        // Get vocabulary
        const struct llama_vocab *vocab = llama_model_get_vocab(model);

        // Check token count and validate against context window
        int max_token_count = llama_n_ctx(ctx);
        int batch_size = 512; // Our configured batch size
        std::vector<llama_token> check_tokens;
        check_tokens.resize(max_token_count);

        int check_n_tokens =
            llama_tokenize(vocab, input, strlen(input), check_tokens.data(),
                           check_tokens.size(), true, false);
        if (check_n_tokens < 0) {
            NSLog(@"Error: Too many tokens for context: %d needed",
                  -check_n_tokens);
            return @"Error: Your query is too long. Please provide a shorter "
                   @"description of your emergency.";
        }

        // Only trim history when approaching n_ctx limit (90% of context window)
        if (check_n_tokens > max_token_count * 0.9) {
            NSLog(@"Token count %d approaching context limit %d, trimming history", 
                  check_n_tokens, max_token_count);
            if (conversationHistory.count > 2) {
                [conversationHistory removeObjectsAtIndexes:
                    [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]];
                NSLog(@"Trimmed oldest history entries to fit context");
                return [self runPrompt:prompt]; // Retry with reduced history
            } else {
                return @"Error: Context full. Please start a new conversation.";
            }
        }

        // Tokenize
        std::vector<llama_token> tokens;
        tokens.resize(check_n_tokens);
        int n_tokens =
            llama_tokenize(vocab, input, strlen(input), tokens.data(),
                           tokens.size(), true, false);
        if (n_tokens < 0) {
            NSLog(@"Error: Failed to tokenize input");
            return @"Error: Failed to tokenize input";
        }
        tokens.resize(n_tokens);
        NSLog(@"Tokenized input: %d tokens", n_tokens);

        // KV cache management - clear before starting
        llama_kv_self_clear(ctx);

        // Decode the prompt using chunked processing
        llama_seq_id seq_id = 0;
        int decode_result = [self decodeTokensInChunks:tokens 
                                              startPos:0 
                                             batchSize:batch_size 
                                                 seqId:seq_id];

        // Check for decode error
        if (decode_result != 0) {
            NSLog(@"Error: Failed to process input, error code: %d", decode_result);
            return @"Error: Failed to process input";
        }

        // Generate with bullet point limiting and max_tokens = 200
        std::string result_text;
        llama_seq_id gen_seq_id = 0;

        int max_tokens =
            200; // Increased slightly to ensure complete bullet points
        int bulletCount = 0;
        bool inBulletPoint = false;
        std::string currentBullet = "";

        for (int i = 0; i < max_tokens; i++) {
            llama_token next = llama_sampler_sample(sampler, ctx, -1);

            // Stop if EOS token is reached
            if (next == llama_vocab_eos(vocab)) {
                NSLog(@"Reached end of sequence at token %d", i);
                break;
            }

            // Get token text
            const char *piece = llama_vocab_get_text(vocab, next);
            if (piece == NULL) {
                NSLog(@"Warning: NULL piece received, skipping token");
                continue;
            }

            result_text += piece;

            // Better bullet point detection and completion
            if (strstr(piece, "•") != NULL) {
                bulletCount++;
                inBulletPoint = true;
                currentBullet = "";
                NSLog(@"Found bullet point %d", bulletCount);
            }

            // If we're in a bullet point, track its completion
            if (inBulletPoint) {
                currentBullet += piece;

                // Check if bullet point is complete (has action and
                // description)
                if (strstr(piece, "\n") != NULL ||
                    strstr(piece, "<0x0A>") != NULL) {
                    // Bullet point completed
                    inBulletPoint = false;
                    NSLog(@"Completed bullet point %d: %s", bulletCount,
                          currentBullet.c_str());

                    if (bulletCount >= 5) {
                        NSLog(@"Stopping after completing 5 bullet points");
                        break;
                    }
                }
            }

            // Create a batch for the new token
            struct llama_batch next_batch = {0};
            next_batch.n_tokens = 1;
            next_batch.token = &next;
            next_batch.pos = (llama_pos *)malloc(sizeof(llama_pos));
            next_batch.n_seq_id = (int32_t *)malloc(sizeof(int32_t));
            next_batch.seq_id = (llama_seq_id **)malloc(sizeof(llama_seq_id *));
            next_batch.logits = (int8_t *)malloc(sizeof(int8_t));

            if (!next_batch.pos || !next_batch.n_seq_id || !next_batch.seq_id ||
                !next_batch.logits) {
                free(next_batch.pos);
                free(next_batch.n_seq_id);
                free(next_batch.seq_id);
                free(next_batch.logits);
                NSLog(@"Error: Memory allocation failed during generation");
                break;
            }

            next_batch.pos[0] = n_tokens + i;
            next_batch.n_seq_id[0] = 1;
            next_batch.seq_id[0] = &gen_seq_id;
            next_batch.logits[0] = 1;

            int decode_result = llama_decode(ctx, next_batch);

            free(next_batch.pos);
            free(next_batch.n_seq_id);
            free(next_batch.seq_id);
            free(next_batch.logits);

            if (decode_result != 0) {
                NSLog(@"Error during generation, stopping: %d", decode_result);
                break;
            }

            llama_sampler_accept(sampler, next);
        }

        // If no text was generated, return a helpful message
        if (result_text.empty()) {
            NSLog(@"No text was generated");
            return @"I'm survivAI, your emergency assistant. What situation "
                   @"are you facing?";
        }

        NSLog(@"Generated text: %s", result_text.c_str());

        // Clean up the generated text
        NSString *cleanedText = [self
            cleanGeneratedText:[NSString
                                   stringWithUTF8String:result_text.c_str()]];

        // Add to conversation history
        [self addToHistory:prompt response:cleanedText];

        return cleanedText;
    } @catch (NSException *exception) {
        NSLog(@"Exception during processing: %@", exception);
        return @"Error processing your request. Please try again.";
    }
}

- (void)dealloc {
    if (sampler) {
        llama_sampler_free(sampler);
        sampler = NULL;
    }

    if (ctx) {
        llama_free(ctx);
        ctx = NULL;
    }

    if (model) {
        llama_model_free(model);
        model = NULL;
    }

    NSLog(@"LLMWrapper deallocated");
}

@end

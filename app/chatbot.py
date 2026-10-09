from app.agent import llm
from app.tools import get_log_expense_tool, get_query_transactions_sql_tool, get_rag_financial_knowledge_tool

def chat_with_expensly(user_message: str, user_id: int) -> str:
    """
    The main LangChain entrypoint. Takes a user message and orchestrates the tools.
    """
    # 1. Create secure, multi-tenant tools bound to this user
    log_expense_tool = get_log_expense_tool(user_id)
    query_transactions_sql_tool = get_query_transactions_sql_tool(user_id)
    rag_financial_knowledge_tool = get_rag_financial_knowledge_tool()
    
    tools = [log_expense_tool, query_transactions_sql_tool, rag_financial_knowledge_tool]
    tools_map = {tool.name: tool for tool in tools}
    
    # 2. Bind the tools to the LLM
    llm_with_tools = llm.bind_tools(tools)

    # 3. Give the agent its core personality and instructions
    messages = [
        ("system", "You are Expensly, a highly intelligent personal finance assistant. "
                   "If a user tells you about a new expense, you MUST use the 'log_expense_tool' to save it. "
                   "If a user asks about their past spending or analytics, you MUST use the 'query_transactions_sql_tool'. "
                   "If a user asks for general financial advice, budgeting rules, or tips, you MUST use the 'rag_financial_knowledge_tool'. "
                   "If you need clarification from the user, just ask politely."),
        ("user", user_message)
    ]
    
    # 4. First call to the LLM to see if it wants to use a tool
    ai_msg = llm_with_tools.invoke(messages)
    messages.append(ai_msg)
    
    # If the LLM decided to call a tool, we execute it here!
    if ai_msg.tool_calls:
        for tool_call in ai_msg.tool_calls:
            tool_to_call = tools_map.get(tool_call["name"])
            if tool_to_call:
                tool_msg = tool_to_call.invoke(tool_call)
                messages.append(tool_msg)
        
        # 5. Call the LLM one last time so it can summarize the tool's result to the user
        final_msg = llm_with_tools.invoke(messages)
        content = final_msg.content
        if isinstance(content, list):
            # Gemini sometimes returns a list of text blocks
            content = " ".join([block.get("text", "") for block in content if isinstance(block, dict) and "text" in block])
        return str(content)
        
    # If it didn't use a tool, just return its conversational response
    content = ai_msg.content
    if isinstance(content, list):
        content = " ".join([block.get("text", "") for block in content if isinstance(block, dict) and "text" in block])
    return str(content)

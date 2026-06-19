exports.handler = async (event) => {
  const name = event.queryStringParameters?.name || 'World 123 456';
  
  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: `Hello, ${name}!` }),
  };
};

window.onload = function() {
  todoDB.open(refreshTodos);

  var newTodoForm = document.getElementById('new-todo-form');
  var newTodoInput = document.getElementById('new-todo');

  newTodoForm.onsubmit = function() {
    var text = newTodoInput.value;

    // Check to make sure the text is not blank
    if (text.replace(/ /g,'') != '') {
      // Create it
      todoDB.createTodo(text, function(todo) {
        refreshTodos();
      });
    }

    // Reset the input field
    newTodoInput.value = '';

    // Don't actually send the form
    return false;
  };
};

function refreshTodos() {
  todoDB.fetchTodos(function(todos) {
    var todoList = document.getElementById('todo-items');
    todoList.innerHTML = '';

    for (var i = 0; i < todos.length; i++) {
      // Most recent first
      var todo = todos[(todos.length - 1 - i)];

      var li = document.createElement('li');
      li.id = 'todo-' + todo.timestamp;
      var checkbox = document.createElement('input');
      checkbox.type = "checkbox";
      checkbox.className = "todo-checkbox";
      checkbox.setAttribute('data-id', todo.timestamp);

      li.appendChild(checkbox);

      var span = document.createElement('span');
      span.innerHTML = todo.text;

      li.appendChild(span);

      todoList.appendChild(li);

      // Setup an event listener for the checkbox
      checkbox.addEventListener('click', function(e) {
        var id = parseInt(e.target.getAttribute('data-id'));

        todoDB.deleteTodo(id, refreshTodos);
      });
    }
  });
}

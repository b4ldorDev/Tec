// To-Do List Application
class TodoApp {
    constructor() {
        this.tasks = [];
        this.currentFilter = 'all';
        this.editingTaskId = null;
        
        // Initialize the application
        this.init();
    }

    init() {
        // Load tasks from localStorage
        this.loadTasksFromStorage();
        
        // Bind event listeners
        this.bindEventListeners();
        
        // Render initial state
        this.render();
    }

    // Event Listeners
    bindEventListeners() {
        const taskInput = document.getElementById('taskInput');
        const addButton = document.getElementById('addButton');
        const filterButtons = document.querySelectorAll('.filter-btn');
        const clearCompletedBtn = document.getElementById('clearCompleted');
        const taskList = document.getElementById('taskList');

        // Add task events
        addButton.addEventListener('click', () => this.addTask());
        taskInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.addTask();
            }
        });

        // Filter events
        filterButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.setFilter(e.target.dataset.filter);
            });
        });

        // Clear completed tasks
        clearCompletedBtn.addEventListener('click', () => this.clearCompletedTasks());

        // Task list events (delegation)
        taskList.addEventListener('click', (e) => this.handleTaskListClick(e));
        taskList.addEventListener('dblclick', (e) => this.handleTaskDoubleClick(e));
        taskList.addEventListener('keypress', (e) => this.handleTaskKeyPress(e));
        taskList.addEventListener('blur', (e) => this.handleTaskBlur(e), true);
    }

    // Task Management
    addTask() {
        const taskInput = document.getElementById('taskInput');
        const taskText = taskInput.value.trim();

        if (!taskText) {
            this.showInputError('Please enter a task');
            return;
        }

        const newTask = {
            id: this.generateId(),
            text: taskText,
            completed: false,
            createdAt: new Date().toISOString()
        };

        this.tasks.unshift(newTask); // Add to beginning of array
        taskInput.value = '';
        
        this.saveTasksToStorage();
        this.render();
        
        // Focus back on input for better UX
        taskInput.focus();
    }

    toggleTask(taskId) {
        const task = this.tasks.find(t => t.id === taskId);
        if (task) {
            task.completed = !task.completed;
            task.updatedAt = new Date().toISOString();
            
            this.saveTasksToStorage();
            this.render();
        }
    }

    deleteTask(taskId) {
        // Add animation class before removing
        const taskElement = document.querySelector(`[data-task-id="${taskId}"]`);
        if (taskElement) {
            taskElement.classList.add('removing');
            
            setTimeout(() => {
                this.tasks = this.tasks.filter(t => t.id !== taskId);
                this.saveTasksToStorage();
                this.render();
            }, 300);
        }
    }

    editTask(taskId) {
        const task = this.tasks.find(t => t.id === taskId);
        if (!task) return;

        this.editingTaskId = taskId;
        this.render();

        // Focus on the input field
        const inputField = document.querySelector(`[data-task-id="${taskId}"] .task-input`);
        if (inputField) {
            inputField.focus();
            inputField.select();
        }
    }

    saveTaskEdit(taskId, newText) {
        const trimmedText = newText.trim();
        
        if (!trimmedText) {
            // If empty, delete the task
            this.deleteTask(taskId);
            return;
        }

        const task = this.tasks.find(t => t.id === taskId);
        if (task) {
            task.text = trimmedText;
            task.updatedAt = new Date().toISOString();
        }

        this.editingTaskId = null;
        this.saveTasksToStorage();
        this.render();
    }

    cancelEdit() {
        this.editingTaskId = null;
        this.render();
    }

    clearCompletedTasks() {
        const completedCount = this.tasks.filter(t => t.completed).length;
        
        if (completedCount === 0) return;

        if (confirm(`Are you sure you want to delete ${completedCount} completed task${completedCount > 1 ? 's' : ''}?`)) {
            this.tasks = this.tasks.filter(t => !t.completed);
            this.saveTasksToStorage();
            this.render();
        }
    }

    // Filtering
    setFilter(filter) {
        this.currentFilter = filter;
        
        // Update active filter button
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.filter === filter);
        });
        
        this.render();
    }

    getFilteredTasks() {
        switch (this.currentFilter) {
            case 'active':
                return this.tasks.filter(t => !t.completed);
            case 'completed':
                return this.tasks.filter(t => t.completed);
            default:
                return this.tasks;
        }
    }

    // Event Handlers
    handleTaskListClick(e) {
        const taskItem = e.target.closest('.task-item');
        if (!taskItem) return;

        const taskId = taskItem.dataset.taskId;

        if (e.target.classList.contains('task-checkbox')) {
            this.toggleTask(taskId);
        } else if (e.target.classList.contains('delete-btn') || e.target.closest('.delete-btn')) {
            this.deleteTask(taskId);
        } else if (e.target.classList.contains('edit-btn') || e.target.closest('.edit-btn')) {
            this.editTask(taskId);
        }
    }

    handleTaskDoubleClick(e) {
        if (e.target.classList.contains('task-text')) {
            const taskItem = e.target.closest('.task-item');
            if (taskItem) {
                this.editTask(taskItem.dataset.taskId);
            }
        }
    }

    handleTaskKeyPress(e) {
        if (e.key === 'Enter' && e.target.classList.contains('task-input')) {
            const taskItem = e.target.closest('.task-item');
            if (taskItem) {
                this.saveTaskEdit(taskItem.dataset.taskId, e.target.value);
            }
        } else if (e.key === 'Escape' && e.target.classList.contains('task-input')) {
            this.cancelEdit();
        }
    }

    handleTaskBlur(e) {
        if (e.target.classList.contains('task-input')) {
            const taskItem = e.target.closest('.task-item');
            if (taskItem) {
                this.saveTaskEdit(taskItem.dataset.taskId, e.target.value);
            }
        }
    }

    // Rendering
    render() {
        this.renderTaskList();
        this.renderTaskCounter();
        this.renderClearButton();
        this.renderEmptyState();
    }

    renderTaskList() {
        const taskList = document.getElementById('taskList');
        const filteredTasks = this.getFilteredTasks();

        taskList.innerHTML = filteredTasks.map(task => this.createTaskHTML(task)).join('');
    }

    createTaskHTML(task) {
        const isEditing = this.editingTaskId === task.id;
        
        return `
            <li class="task-item ${task.completed ? 'completed' : ''} ${isEditing ? 'editing' : ''}" 
                data-task-id="${task.id}">
                <input 
                    type="checkbox" 
                    class="task-checkbox" 
                    ${task.completed ? 'checked' : ''}
                    aria-label="Mark task as ${task.completed ? 'incomplete' : 'complete'}"
                >
                ${isEditing ? 
                    `<input type="text" class="task-input" value="${this.escapeHtml(task.text)}" maxlength="200">` :
                    `<span class="task-text ${task.completed ? 'completed' : ''}">${this.escapeHtml(task.text)}</span>`
                }
                <div class="task-actions">
                    <button class="edit-btn" aria-label="Edit task" title="Edit task">
                        ✏️
                    </button>
                    <button class="delete-btn" aria-label="Delete task" title="Delete task">
                        🗑️
                    </button>
                </div>
            </li>
        `;
    }

    renderTaskCounter() {
        const activeCount = this.tasks.filter(t => !t.completed).length;
        const activeCountElement = document.getElementById('activeCount');
        
        activeCountElement.textContent = activeCount;
        
        // Update the text based on count
        const counterElement = activeCountElement.parentElement;
        counterElement.innerHTML = `<span id="activeCount">${activeCount}</span> ${activeCount === 1 ? 'task' : 'tasks'} remaining`;
    }

    renderClearButton() {
        const clearBtn = document.getElementById('clearCompleted');
        const completedCount = this.tasks.filter(t => t.completed).length;
        
        clearBtn.style.display = completedCount > 0 ? 'block' : 'none';
    }

    renderEmptyState() {
        const emptyState = document.getElementById('emptyState');
        const filteredTasks = this.getFilteredTasks();
        
        emptyState.style.display = filteredTasks.length === 0 ? 'block' : 'none';
        
        // Update empty state message based on filter
        const message = this.getEmptyStateMessage();
        emptyState.querySelector('p').textContent = message;
    }

    getEmptyStateMessage() {
        switch (this.currentFilter) {
            case 'active':
                return this.tasks.length === 0 ? 'No tasks yet. Add one above!' : 'No active tasks! 🎉';
            case 'completed':
                return 'No completed tasks yet.';
            default:
                return 'No tasks yet. Add one above!';
        }
    }

    // Local Storage
    saveTasksToStorage() {
        try {
            localStorage.setItem('todoAppTasks', JSON.stringify(this.tasks));
        } catch (error) {
            console.error('Failed to save tasks to localStorage:', error);
            this.showError('Failed to save tasks. Please try again.');
        }
    }

    loadTasksFromStorage() {
        try {
            const storedTasks = localStorage.getItem('todoAppTasks');
            if (storedTasks) {
                this.tasks = JSON.parse(storedTasks);
                
                // Validate tasks data structure
                this.tasks = this.tasks.filter(task => 
                    task && 
                    typeof task.id === 'string' && 
                    typeof task.text === 'string' && 
                    typeof task.completed === 'boolean'
                );
            }
        } catch (error) {
            console.error('Failed to load tasks from localStorage:', error);
            this.tasks = [];
            this.showError('Failed to load saved tasks.');
        }
    }

    // Utility Functions
    generateId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    showInputError(message) {
        const taskInput = document.getElementById('taskInput');
        const originalPlaceholder = taskInput.placeholder;
        
        taskInput.style.borderColor = '#ef4444';
        taskInput.placeholder = message;
        
        setTimeout(() => {
            taskInput.style.borderColor = '';
            taskInput.placeholder = originalPlaceholder;
        }, 2000);
    }

    showError(message) {
        // Simple error display - could be enhanced with a toast notification
        console.error(message);
        alert(message);
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.todoApp = new TodoApp();
});

// Handle page visibility change to save state
document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden' && window.todoApp) {
        window.todoApp.saveTasksToStorage();
    }
});

// Handle beforeunload to save state
window.addEventListener('beforeunload', () => {
    if (window.todoApp) {
        window.todoApp.saveTasksToStorage();
    }
});
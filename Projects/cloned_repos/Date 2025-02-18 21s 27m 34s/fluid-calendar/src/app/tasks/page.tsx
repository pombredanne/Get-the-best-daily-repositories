"use client";

import { useState, useEffect } from "react";
import { TaskList } from "@/components/tasks/TaskList";
import { BoardView } from "@/components/tasks/BoardView/BoardView";
import { TaskModal } from "@/components/tasks/TaskModal";
import { useTaskStore } from "@/store/task";
import { useProjectStore } from "@/store/project";
import { useTaskPageSettings } from "@/store/taskPageSettings";
import { Task, TaskStatus, NewTask } from "@/types/task";
import { ProjectSidebar } from "@/components/projects/ProjectSidebar";
import { BsListTask, BsKanban } from "react-icons/bs";
import { cn } from "@/lib/utils";

export default function TasksPage() {
  const {
    tasks,
    tags,
    loading,
    error,
    fetchTasks,
    fetchTags,
    createTask,
    updateTask,
    deleteTask,
    createTag,
    scheduleAllTasks,
  } = useTaskStore();
  const { fetchProjects } = useProjectStore();
  const { viewMode, setViewMode } = useTaskPageSettings();

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedTask, setSelectedTask] = useState<Task | undefined>();

  // Fetch tasks and tags on mount
  useEffect(() => {
    fetchTasks();
    fetchTags();
    fetchProjects();
  }, [fetchTasks, fetchTags, fetchProjects]);

  const handleCreateTask = async (task: NewTask) => {
    await createTask(task);
    await fetchTasks();
    await fetchProjects();
  };

  const handleUpdateTask = async (task: NewTask) => {
    if (selectedTask) {
      await updateTask(selectedTask.id, task);
      await fetchTasks();
      await fetchProjects();
    }
  };

  const handleDeleteTask = async (taskId: string) => {
    if (confirm("Are you sure you want to delete this task?")) {
      await deleteTask(taskId);
      await fetchTasks();
      await fetchProjects();
    }
  };

  const handleStatusChange = async (taskId: string, status: TaskStatus) => {
    await updateTask(taskId, { status });
    await fetchTasks();
    await fetchProjects();
  };

  const handleCreateTag = async (name: string, color?: string) => {
    try {
      const newTag = await createTag({ name, color });
      await fetchTags(); // Refresh tags after creation
      return newTag;
    } catch (error) {
      console.error("Error creating tag:", error);
      throw error;
    }
  };

  const handleInlineEdit = async (task: Task) => {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { id, tags, createdAt, updatedAt, project, ...updates } = task;
    console.log("Updating task:", { id, updates });
    await updateTask(id, updates);
    await fetchTasks();
    // If projectId was changed, refresh projects to update task counts
    if ("projectId" in updates) {
      await fetchProjects();
    }
  };

  return (
    <div className="flex h-full">
      <ProjectSidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <div className="px-6 py-4 border-b">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <h1 className="text-2xl font-bold text-gray-900">Tasks</h1>
              <div className="flex items-center gap-1 bg-gray-100 rounded-lg p-1">
                <button
                  onClick={() => setViewMode("list")}
                  className={cn(
                    "p-2 rounded-md text-sm font-medium flex items-center gap-2",
                    viewMode === "list"
                      ? "bg-white text-gray-900 shadow-sm"
                      : "text-gray-500 hover:text-gray-900"
                  )}
                >
                  <BsListTask className="h-4 w-4" />
                  List
                </button>
                <button
                  onClick={() => setViewMode("board")}
                  className={cn(
                    "p-2 rounded-md text-sm font-medium flex items-center gap-2",
                    viewMode === "board"
                      ? "bg-white text-gray-900 shadow-sm"
                      : "text-gray-500 hover:text-gray-900"
                  )}
                >
                  <BsKanban className="h-4 w-4" />
                  Board
                </button>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => {
                  if (
                    confirm(
                      "Auto-schedule all tasks marked for auto-scheduling?"
                    )
                  ) {
                    scheduleAllTasks();
                  }
                }}
                className="px-4 py-2 rounded-md bg-blue-100 text-blue-700 text-sm font-medium hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Auto Schedule
              </button>
              <button
                onClick={() => {
                  setSelectedTask(undefined);
                  setIsModalOpen(true);
                }}
                className="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Create Task
              </button>
            </div>
          </div>

          {error && (
            <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-md">
              Error: {error.message}
            </div>
          )}
        </div>

        <div className="flex-1 overflow-hidden flex flex-col min-h-0 p-6">
          {viewMode === "list" ? (
            <TaskList
              tasks={tasks}
              onEdit={(task) => {
                setSelectedTask(task);
                setIsModalOpen(true);
              }}
              onDelete={handleDeleteTask}
              onStatusChange={handleStatusChange}
              onInlineEdit={handleInlineEdit}
            />
          ) : (
            <BoardView
              tasks={tasks}
              onEdit={(task) => {
                setSelectedTask(task);
                setIsModalOpen(true);
              }}
              onDelete={handleDeleteTask}
              onStatusChange={handleStatusChange}
            />
          )}
        </div>

        <TaskModal
          isOpen={isModalOpen}
          onClose={() => {
            setIsModalOpen(false);
            setSelectedTask(undefined);
          }}
          onSave={selectedTask ? handleUpdateTask : handleCreateTask}
          task={selectedTask}
          tags={tags}
          onCreateTag={handleCreateTag}
        />

        {loading && (
          <div className="fixed inset-0 bg-black/30 flex items-center justify-center">
            <div className="bg-white rounded-lg p-4">Loading...</div>
          </div>
        )}
      </div>
    </div>
  );
}

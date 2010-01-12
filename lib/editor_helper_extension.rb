#
# Copyright 2000-2009 JetBrains s.r.o.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'editor_action_helper'

# TODO - remove after RubyMine 2.0.1 final release
class EditorWrapper
  def delete_selected_text
    EditorModificationUtil::delete_selected_text @editor
  end

  def method_missing(name, *args, &block)
    @editor.send(name, *args, &block)
  end

  def text
    @editor.getDocument.getText
  end

  def caret_offset
    @editor.caret_model.get_offset
  end
end

class RubyEditorAction < AnAction
  def initialize(id, options)
    super(options[:text], options[:description], nil)
    @id = id
    file_types = options[:file_type]
    @file_types = case file_types
      when Array
        file_types
      when String
       [file_types]
      else
       nil
    end
    @block = options[:block]
    # enable in Modal dialogs, e.g. rename refactoring dialog, search, etc.
    setEnabledInModalContext(true) if options[:enable_in_modal_context]
  end

  def actionPerformed(e)
    project = e.get_data PlatformDataKeys::PROJECT
    editor = e.get_data PlatformDataKeys::EDITOR
    file = e.get_data LangDataKeys::PSI_FILE
    ExecuteHelper.run_as_command_in_write_action(project, @id) do
      if file
        CommonRefactoringUtil.check_read_only_status project, file
      end

      @block.call EditorWrapper.new(editor), file
    end
  end

  def update(e)
    project = e.get_data PlatformDataKeys::PROJECT
    editor = e.get_data PlatformDataKeys::EDITOR
    file = e.get_data LangDataKeys::PSI_FILE
    e.presentation.enabled = is_enabled(project,editor,file)
  end

  def is_enabled(project, editor, file)
    if project.nil? or editor.nil?
      return false
    end
    unless @file_types.nil?
      return false if file.nil?
      return false unless @file_types.inject(false) { |memo, file_type| memo || file.file_type.name == file_type }
    end
    true
  end
end

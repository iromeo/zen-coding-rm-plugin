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

include Java

require "yaml"

# Import some RubyMine Java API
import com.intellij.codeInsight.template.TemplateBuilder unless defined? TemplateBuilder
import com.intellij.codeInsight.template.Template unless defined? Template
import com.intellij.codeInsight.template.TemplateManager unless defined? TemplateManager
import com.intellij.codeInsight.template.impl.VariableNode unless defined? VariableNode
import org.jetbrains.plugins.ruby.ruby.lang.TextUtil unless defined? TextUtil

module ZenHelper
  SETTINGS = YAML::load_file(File.dirname(__FILE__) + '/../config.yml')

  def determine_abbreviation_offsets(editor)
    if editor.has_selection?
      return editor.selection_start..editor.selection_end
    else
      caret_offset = editor.caret_offset
      # find preceding whitespace
      if caret_offset > 0
        snippet_start = find_snippet_start_index(editor.text, caret_offset - 1)
        return snippet_start..caret_offset
      end
    end
    return nil
  end

  def find_snippet_start_index(text, current_char_index)
    # let's find preceding whitespace and return next char
    current_char_index.downto 0 do | i |
      char = text[i,1]
      if TextUtil.isWhiteSpaceOrEol(text[i]) || char == '\'' || char == '"'
        return i + 1
      end
    end
    return 0
  end

  def determine_snippet_scope(file, editor)
    #let's determine scope as mime types of language in the beginning of template
    snippet_start = if editor.has_selection?
      editor.selection_start
    else
      caret_offset = editor.caret_offset
      caret_offset > 0 ? find_snippet_start_index(editor.text, caret_offset - 1) : nil
    end
    return nil if snippet_start.nil?
    psi_element = file.getViewProvider.findElementAt(snippet_start)
    lang = psi_element.getLanguage

    mimeTypes = lang.getMimeTypes
    mimeTypes.inject("") {|memo, mime_type| memo + mime_type.downcase}
  end

  def eval_tm_snippet(abbr, file, editor)
    ENV['TM_BUNDLE_SUPPORT'] = File.expand_path("../"+ @zc_tm_bundle_relative_path + "/Support", File.dirname(__FILE__))
    # ENV['TM_LINE_ENDING'] = ..
    ENV['TM_CURRENT_LINE'] = '0'
    ENV['TM_LINE_INDEX'] = '0'
    ENV['TM_SCOPE'] = determine_snippet_scope(file, editor)
    ENV['TM_SELECTED_TEXT'] = abbr

    `#{SETTINGS['python']} #{File.expand_path("expand_abbreviation.py", File.dirname(__FILE__))}`
  end

  def build_rm_template (snippet_text, file)
    manager = TemplateManager.getInstance(file.getProject())
    template = manager.createTemplate("", "")

    # split template text to text and variables segments
    items = snippet_text.split(/\$(\d)+/)
    variable_mode = false
    items.each do |item|
      if variable_mode
        # of only 1 variable - let's replace it with end
        if items.size < 4
          template.addEndVariable
        else
          # several variables
          # $0 in TM is similar to $END$ in RubyMine
          if item == '0'
            template.addEndVariable
          else
            var_name = "VALUE_#{item}"
            # insert variable segment
            template.addVariable(var_name, VariableNode.new(var_name, nil), true)
          end
        end
      else
        # insert text segment
        template.addTextSegment(item)
      end
      variable_mode = !variable_mode
    end
    # if doesn't contain variables - add 'end' segment
    template.addEndVariable unless items.size > 1

    # indent and reformat template
    template.setToIndent(SETTINGS['reformat_snippet']);
    template.setToReformat(SETTINGS['indent_snippet']);
    template
  end

  def remove_abbreviation(editor, abbr_range)
    editor.select( abbr_range.min, abbr_range.max)
    #remove abbreviation
    editor.delete_selected_text
  end

  def apply_template(editor, template, file)
    #  editor.getCaretModel().moveToOffset(methodRange.getStartOffset());
    #  editor.getDocument().deleteString(methodRange.getStartOffset(), methodRange.getEndOffset());
    TemplateManager.getInstance(file.getProject()).startTemplate(editor, template);
  end
end
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

require 'editor_action_helper'

# remove after 2.0.1 official release
require File.expand_path(File.dirname(__FILE__) + '/../lib/editor_helper_extension')
require File.expand_path(File.dirname(__FILE__) + '/../lib/zen_helper')

import com.intellij.openapi.ui.Messages unless defined? Messages

class ZenCodingAction
  extend ZenHelper

  def self.tm_bundle_relative_path= path
    @zc_tm_bundle_relative_path = path
  end

  def self.perform_action(editor, file)
    abbr_offsets = determine_abbreviation_offsets(editor)

    # stop if no abbreviation
    unless abbr_offsets.nil?
      abbr = editor.text[abbr_offsets.min..abbr_offsets.max - 1]
      snippet_text = eval_tm_snippet(abbr, file, editor)
      # stop if snippet wasn't recognized
      unless snippet_text.empty?
        template = build_rm_template(snippet_text, file)
        # remove abbreviation before template will be inserted
        remove_abbreviation(editor, abbr_offsets)

        apply_template(editor, template, file)
      else
        Messages.showErrorDialog("Template '#{abbr}' isn't correct!", "Zen Conding Error")
      end
    end
  end
end

# path to Zen-Coding TextMate Bundle
ZenCodingAction.tm_bundle_relative_path = "zen-coding-read-only/plugins/TextMate/Zen Coding.tmbundle" 

register_editor_action "ExpandZenCodingTemplate",
                       :text => "Expand Zen-Coding Template",
                       :description => "Expands Zen-Coding template for selected text or for text under cursor",
                       :shortcut => "control shift J",
                       :group => :extensions,
                       :file_type => "RHTML" do |editor, file|
  unless file.nil?
    ZenCodingAction.perform_action(editor, file)
  end
end
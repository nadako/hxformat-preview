import haxe.Json;
import vscode.*;
import Vscode.*;
import haxe.io.Bytes;
using StringTools;

class DefaultConfigProvider {
	var completion:Array<CompletionItem>;

	public function new() {
		var parser = new json2object.JsonParser<formatter.config.FormatterConfig>();
		var config = parser.fromJson("{}", "default-hxformat.json");
		var item = new CompletionItem("hxformat defaults", Snippet);
		item.insertText = Json.stringify(config, "\t");
		completion = [item];
		languages.registerCompletionItemProvider("json", {provideCompletionItems: provideCompletionItems});
	}

	public function provideCompletionItems(document:TextDocument, position:Position, token:CancellationToken, context:CompletionContext):Array<CompletionItem> {
		if (document.getText() == "") {
			return completion;
		} else {
			return null;
		}
	}
}

class FormatterPreview {
	var sample:Bytes;
	var config = new formatter.config.Config();
	var formatter = new formatter.Formatter();
	var didChange = new EventEmitter();
	var uri = Uri.parse("hxformat:///Sample.hx");

	public var onDidChange:Event<Uri>;

	public function new(sample:Bytes) {
		this.sample = sample;
		onDidChange = didChange.event;
		workspace.registerTextDocumentContentProvider("hxformat", this);

		commands.registerCommand("hxformat-preview.open", function() {
			var editor = window.activeTextEditor;
			if (editor == null)
				return;

			if (!editor.document.fileName.endsWith("hxformat.json"))
				return;

			var doc = editor.document;

			window.showTextDocument(uri, {viewColumn: Beside, preview: true, preserveFocus: true}).then(function(editor) {
				workspace.onDidChangeTextDocument(function(event) {
					if (event.document != doc) return;
					config.readConfigFromString(doc.getText(), "hxformat.json");
					didChange.fire(uri);
				});
			});
		});
	}

	public function provideTextDocumentContent(_, _) {
		var result = formatter.formatFileWithConfig({name: "Sample.hx", content: sample}, config);
		return switch (result) {
			case Success(formattedCode): formattedCode;
			case Failure(errorMessage): errorMessage;
			case Disabled: throw "should not happen";
		};
	}

}

class Main {
	@:expose("activate")
	static function activate(context:ExtensionContext) {
		new DefaultConfigProvider();
		new FormatterPreview(js.node.Fs.readFileSync(context.extensionPath + "/Sample.hx").hxToBytes());
	}
}

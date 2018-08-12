function tryHighlightPatched(str, lang) {
    try {
        var matching = str.match(/(\r?\n)/);
        var separator = matching ? matching[1] : '';
        var lines = matching ? str.split(separator) : [str];

        var html = '';
        var result;
        do {
            var top = result ? result.top : null;
            var currentLine = lines.shift();
            var remainingLines = lines.length;

            // End line characters may be used in highlightjs end delimiter expressions
            if (remainingLines > 0) {
                currentLine += separator;
            }

            result = hljs.highlight(lang, currentLine, false, top);
            html += result.value;
        } while(remainingLines > 0);

        result.value = html;
        return result;
    } catch (err) {

    }
}
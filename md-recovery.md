## The MD status and required recovery at the start timing

| Node1	| Node2	| Required recovery operation on starting Node1
|----	|----	|----
|RED	|GREEN	| <code> mdctrl -r [MD] </code>
|	|RED	| MD is recovered completely at first on the group starting<br><code> mdctrl -f [MD]; mdctrl -r [MD]</code><br>
|	|GRAY	| <code> mdctrl -f [MD]</code>
|GREEN	|GREEN	| Nothing needed
|	|RED	| Will be automatically recoverd by "mdw"
|	|GRAY	| No way to deal with

- クラスタ起動時

- グループ起動時


	

local Review = require("sidekick_reader.review")

local parsed = assert(Review.parse([[
diff --git a/src/lib.rs b/src/lib.rs
--- a/src/lib.rs
+++ b/src/lib.rs
@@ -1,2 +1,2 @@
 keep
-old
+new
diff --git a/src/new.rs b/src/new.rs
new file mode 100644
--- /dev/null
+++ b/src/new.rs
@@ -0,0 +1,2 @@
+first
+second
diff --git a/src/old.rs b/src/old.rs
deleted file mode 100644
--- a/src/old.rs
+++ /dev/null
@@ -1 +0,0 @@
-gone
]]))

assert(#parsed.files.working == 3, "all files in the turn diff should be reviewable")
assert(parsed.files.working[1].path == "src/lib.rs" and parsed.files.working[1].status == "M")
assert(parsed.data["src/lib.rs"].left[2] == "old" and parsed.data["src/lib.rs"].right[2] == "new")
assert(parsed.files.working[2].status == "A" and #parsed.data["src/new.rs"].left == 0)
assert(parsed.data["src/new.rs"].right[2] == "second")
assert(parsed.files.working[3].status == "D" and #parsed.data["src/old.rs"].right == 0)

local opened
local view, err = Review.open("diff", "/project", {
	parse = function()
		return parsed
	end,
	open_view = function(options)
		opened = options
		return { opened = true }
	end,
})
assert(view and not err and opened, "review data should be handed to the diff view without temporary files")
assert(opened.data == parsed.data and opened.files == parsed.files)

print("review_spec: ok")

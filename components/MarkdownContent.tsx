// deno-lint-ignore-file react-no-danger -- @deno/gfm sanitizes each rendered fragment.
import BookLayoutObserver from "@/islands/BookLayoutObserver.tsx";
import type { RenderedContent } from "@/lib/markdown.ts";

interface MarkdownContentProps {
  content: RenderedContent;
  id?: string;
}

export function MarkdownContent({ content, id = "book-content" }: MarkdownContentProps) {
  if (content.kind === "flow") {
    return <div class="prose" dangerouslySetInnerHTML={{ __html: content.html }} />;
  }

  return (
    <div class="prose book-prose" id={id}>
      {content.blocks.map((block, blockIndex) =>
        block.kind === "plate"
          ? (
            <div
              class="book-plate"
              data-book-plate
              dangerouslySetInnerHTML={{ __html: block.html }}
            />
          )
          : (
            <div class="book-spread" data-book-spread>
              {block.pages.map((html, pageIndex) => (
                <div
                  class="book-page"
                  data-book-page={`${blockIndex + 1}.${pageIndex + 1}`}
                  dangerouslySetInnerHTML={{ __html: html }}
                />
              ))}
            </div>
          )
      )}
      <BookLayoutObserver targetId={id} />
    </div>
  );
}

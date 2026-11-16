"""profile: students.tags and students.mood_set_at

Revision ID: 0002
Revises: 0001
Create Date: 2026-11-16 21:00:00
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table('students', schema=None) as batch_op:
        batch_op.add_column(sa.Column('mood_set_at', sa.DateTime(timezone=True), nullable=True))
        batch_op.add_column(sa.Column('tags', sa.JSON(), nullable=False, server_default=sa.text("'[]'")))


def downgrade() -> None:
    with op.batch_alter_table('students', schema=None) as batch_op:
        batch_op.drop_column('tags')
        batch_op.drop_column('mood_set_at')
